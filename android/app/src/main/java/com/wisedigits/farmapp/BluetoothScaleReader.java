package com.wisedigits.farmapp;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import io.flutter.plugin.common.EventChannel;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.UUID;

public class BluetoothScaleReader implements SerialListener {
    private static final String TAG = "Gatheru";
    private final Context context;
    private final String deviceAddress;
    private final String scaleModel;
    private EventChannel.EventSink eventSink;
    private final Handler mainLooper = new Handler(Looper.getMainLooper());
    private SerialSocket socket;
    private volatile boolean isConnected = false;
    private final ArrayDeque<byte[]> queue = new ArrayDeque<>();

    private static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    public BluetoothScaleReader(Context context, String deviceAddress, String scaleModel) {
        this.context = context;
        this.deviceAddress = deviceAddress;
        this.scaleModel = scaleModel != null ? scaleModel : "default";
        Log.d(TAG, "BluetoothScaleReader initialized for address: " + deviceAddress + ", model: " + scaleModel);
    }

    public void connectAndReadWeight() {
        Log.d(TAG, "Connecting to scale: " + deviceAddress);
        new Thread(() -> {
            try {
                BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
                if (adapter == null) {
                    sendError("BLUETOOTH_UNAVAILABLE", "Bluetooth not supported", null);
                    return;
                }
                if (!adapter.isEnabled()) {
                    sendError("BLUETOOTH_DISABLED", "Bluetooth is disabled", null);
                    return;
                }
                BluetoothDevice device = adapter.getRemoteDevice(deviceAddress);
                if (device == null) {
                    sendError("DEVICE_NOT_FOUND", "Device not found: " + deviceAddress, null);
                    return;
                }

                socket = new SerialSocket(context, device);
                socket.connect(this);
                isConnected = true;
                Log.d(TAG, "Connected to scale: " + deviceAddress);
                onSerialConnect();
            } catch (IOException e) {
                Log.e(TAG, "Connection failed: " + e.getMessage());
                sendError("BLUETOOTH_ERROR", "Connection error: " + e.getMessage(), null);
                isConnected = false;
                onSerialConnectError(e);
                disconnect(); // Ensure cleanup on failure
            }
        }).start();
    }

    public void disconnect() {
        isConnected = false;
        if (socket != null) {
            socket.disconnect();
            socket = null;
        }
        EventChannel.EventSink sink = eventSink; // Capture reference
        eventSink = null; // Clear immediately to prevent further use
        if (sink != null) {
            mainLooper.post(() -> sink.endOfStream());
        }
    }

    public void setEventSink(EventChannel.EventSink sink) {
        synchronized (eventSinkLock) {
            Log.d(TAG, "Setting EventSink: " + (sink == null ? "null" : "non-null"));
            this.eventSink = sink;
        }
    }

    private final Object eventSinkLock = new Object();

    private void sendError(String code, String message, Object details) {
        synchronized (eventSinkLock) {
            if (eventSink != null) {
                mainLooper.post(() -> {
                    synchronized (eventSinkLock) {
                        if (eventSink != null) {
                            eventSink.error(code, message, details);
                        }
                    }
                });
            }
        }
    }

    @Override
    public void onSerialConnect() {
        Log.d(TAG, "Serial connected");
        mainLooper.post(() -> {
            if (eventSink != null) {
                eventSink.success("Connected");
            }
        });
    }

    @Override
    public void onSerialConnectError(Exception e) {
        Log.e(TAG, "Serial connect error: " + e.getMessage());
        sendError("CONNECTION_ERROR", "Failed to connect: " + e.getMessage(), null);
        disconnect();
    }

    @Override
    public void onSerialRead(byte[] data) {
        Log.d(TAG, "Received data: " + byteArrayToHexString(data));
        synchronized (this) {
            queue.add(data);
            mainLooper.post(() -> {
                ArrayDeque<byte[]> datas;
                synchronized (this) {
                    datas = new ArrayDeque<>(queue);
                    queue.clear();
                }
                onSerialRead(datas);
            });
        }
    }

    @Override 
    public void onSerialRead(ArrayDeque<byte[]> datas) {
        for (byte[] data : datas) {
            float weight = parseWeight(data);
            if (weight >= 0) {
                Log.d("Wambui", "Parsed weight: " + weight);
                mainLooper.post(() -> {
                    if (eventSink != null) {
                        eventSink.success((double) weight);
                    }
                });
            }
        }
    }

    @Override
    public void onSerialIoError(Exception e) {
        Log.e(TAG, "Serial IO error: " + e.getMessage());
        sendError("IO_ERROR", "Serial IO error: " + e.getMessage(), null);
        disconnect();
    }

    private float parseWeight(byte[] data) {
        Log.d(TAG, "Data: " + byteArrayToHexString(data) + ", ASCII: " + new String(data));
        if (data == null || data.length < 2) {
            Log.w(TAG, "Invalid weight data received");
            return 0f;
        }

        String asciiData;

        switch (scaleModel.toLowerCase()) {
            case "your_scale_model":
                asciiData = new String(data).trim();
                Log.d("Wakarindi", asciiData);
                if (asciiData.startsWith("=")) {
                    try {
                        String weightStr = asciiData.substring(1).trim();
                        float weight = Float.parseFloat(weightStr);
                        if (weight < 0 || weight > 100) {
                            Log.w(TAG, "Weight out of range: " + weight);
                            return 0f;
                        }
                        Log.d(TAG, "Parsed ASCII weight: " + weight);
                        return weight;
                    } catch (NumberFormatException e) {
                        Log.w(TAG, "Invalid ASCII weight format: " + asciiData);
                    }
                }
                if ((data[0] & 0xFF) == 61 && (data[1] & 0xFF) == 48) {
                    Log.d(TAG, "Zero weight detected (61 - 48)");
                    return 0f;
                }
                // Swap byte order for big-endian
                int weightInt = ((data[0] & 0xFF) << 8) | (data[1] & 0xFF);
                float weight = weightInt * 0.005f;
                if (weight < 0 || weight > 100) {
                    Log.w(TAG, "Weight out of range: " + weight);
                    return 0f;
                }
                return weight;

            default:
                asciiData = new String(data).trim();
                if (asciiData.startsWith("=") || true) {
                    try {
                        String weightStr = asciiData.substring(1).trim();
                        Log.d("Gatheru", weightStr);
                        weight = Float.parseFloat(weightStr);
                        if (weight < 0) {
                            Log.w(TAG, "Weight out of range 1: " + weight);
                            return 0f;
                        }
                        //weight = reverseWeight(weight+"");
                        weight-=1.4;
                        return weight;
                    } catch (NumberFormatException e) {
                        Log.w(TAG, "Invalid ASCII weight format: " + asciiData);
                    }
                }
                // Swap byte order for big-endian
                weightInt = ((data[0] & 0xFF) << 8) | (data[1] & 0xFF);
                weight = weightInt; // Adjust scaling if needed
                if (weight < 0 || weight > 100) {
                    Log.w(TAG, "Weight out of range: " + weight);
                    return 0f;
                }
                return weight;
        }
    }

    private String byteArrayToHexString(byte[] data) {//Log.d("Wambui",data.toString());
        StringBuilder sb = new StringBuilder();
        for (byte b : data) {
            sb.append(String.format("%02X ", b));
        }
        return sb.toString().trim();
    }

    public static float reverseWeight(String weightStr) {
        if (weightStr == null || weightStr.isEmpty()) {
            Log.w(TAG, "Invalid weight string: null or empty");
            return 0f;
        }

        // Remove leading/trailing whitespace
        weightStr = weightStr.trim();
        Log.d(TAG, "Input weightStr: " + weightStr);

        // Check if the string matches a decimal number format (e.g., "3.22", "3.2200")
        if (!weightStr.matches("\\d+\\.\\d+")) {
            Log.w(TAG, "Invalid weight format: " + weightStr);
            return 0f;
        }

        try {
            // Split the string at the decimal point
            String[] parts = weightStr.split("\\.");
            if (parts.length != 2) {
                Log.w(TAG, "Invalid weight format, expected one decimal point: " + weightStr);
                return 0f;
            }

            // Strip trailing zeros from the fractional part
            String fractionalPart = parts[1].replaceAll("0+$", "");
            // If fractional part is empty, use "0"
            fractionalPart = fractionalPart.isEmpty() ? "0" : fractionalPart;
            String cleanedWeightStr = parts[0] + "." + fractionalPart;
            Log.d(TAG, "Cleaned weightStr: " + cleanedWeightStr);

            // Reverse the integer and fractional parts
            String reversedStr = fractionalPart + "." + parts[0];
            // Ensure valid float format (e.g., ".3" -> "0.3")
            if (reversedStr.startsWith(".")) {
                reversedStr = "0" + reversedStr;
            }
            Log.d(TAG, "Reversed weightStr: " + reversedStr);

            // Parse the reversed string to a float
            float weight = Float.parseFloat(reversedStr);

            // Validate the output range (0 to 100)
            if (weight < 0 || weight > 100) {
                Log.w(TAG, "Reversed weight out of range: " + weight);
                return 0f;
            }

            Log.d(TAG, "Final weight: " + weight);
            return weight;
        } catch (NumberFormatException e) {
            Log.w(TAG, "Failed to parse reversed weight: " + weightStr + ", error: " + e.getMessage());
            return 0f;
        }
    }
}