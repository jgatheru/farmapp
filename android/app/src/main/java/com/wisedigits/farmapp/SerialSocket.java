package com.wisedigits.farmapp;

import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.util.Log;

import java.io.IOException;
import java.io.InputStream;
import java.nio.Buffer;
import java.nio.charset.StandardCharsets;
import java.security.InvalidParameterException;
import java.util.Arrays;
import java.util.UUID;
import java.util.concurrent.Executors;

class SerialSocket implements Runnable {

    private static final UUID BLUETOOTH_SPP = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    private final BroadcastReceiver disconnectBroadcastReceiver;

    private Context context;
    private SerialListener listener;
    private final BluetoothDevice device;
    private BluetoothSocket socket;
    private boolean connected;

    SerialSocket(Context context, BluetoothDevice device) {
        if (context instanceof Activity)
            throw new InvalidParameterException("expected non UI context");
        this.context = context;
        this.device = device;
        disconnectBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (listener != null)
                    listener.onSerialIoError(new IOException("background disconnect"));
                disconnect(); // disconnect now, else would be queued until UI re-attached
            }
        };
    }

    String getName() {
        return device.getName() != null ? device.getName() : device.getAddress();
    }

    /**
     * connect-success and most connect-errors are returned asynchronously to listener
     */
    void connect(SerialListener listener) throws IOException {
        this.listener = listener;
        IntentFilter filter = new IntentFilter(Constants.INTENT_ACTION_DISCONNECT);
        // Fix for Android 13+: Use RECEIVER_NOT_EXPORTED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(disconnectBroadcastReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(disconnectBroadcastReceiver, filter);
        }
        Executors.newSingleThreadExecutor().submit(this);
    }

    void disconnect() {
        Log.d("SerialSocket", "Disconnecting");
        connected = false; // Stop the run loop
        listener = null; // Ignore remaining data and errors
        if (socket != null) {
            try {
                socket.getInputStream().close();
                socket.getOutputStream().close();
                socket.close();
            } catch (Exception e) {
                Log.e("SerialSocket", "Error closing socket: " + e.getMessage(), e);
            }
            socket = null;
        }
        if (context != null) {
            try {
                context.unregisterReceiver(disconnectBroadcastReceiver);
            } catch (IllegalArgumentException e) {
                Log.e("SerialSocket", "Receiver not registered: " + e.getMessage());
            } catch (Exception e) {
                Log.e("SerialSocket", "Error unregistering receiver: " + e.getMessage(), e);
            }
            context = null;
        }
    }

    void write(byte[] data) throws IOException {
        if (!connected)
            throw new IOException("not connected");
        socket.getOutputStream().write(data);
    }

    @Override
    public void run() { // connect & read
        try {
            socket = device.createRfcommSocketToServiceRecord(BLUETOOTH_SPP);
            socket.connect();
            if (listener != null)
                listener.onSerialConnect();
        } catch (Exception e) {
            if (listener != null)
                listener.onSerialConnectError(e);
            try {
                socket.close();
            } catch (Exception ignored) {
            }
            socket = null;
            return;
        }

        connected = true;
        try {
            byte[] buffer = new byte[1024];
            int len;
            byte[] previousData = null;

            //noinspection InfiniteLoopStatement
            while (true) {

                len = socket.getInputStream().read(buffer);

                byte[] data = new byte[len];

                System.arraycopy(buffer, 0, data, 0, len);

                // Compare the current data with the previous data
                if (previousData != null && Arrays.equals(previousData, data)) {
                    // If data is unchanged, wait for a few microseconds before the next read
                    Thread.sleep(5 * 1000);
                }

                previousData = data.clone(); // Update the previous data

                if (listener != null) {
                    listener.onSerialRead(data);
                }
            }
        } catch (Exception e) {
            connected = false;
            if (listener != null)
                listener.onSerialIoError(e);
            try {
                socket.close();
            } catch (Exception ignored) {
            }
            socket = null;
        }
    }

}