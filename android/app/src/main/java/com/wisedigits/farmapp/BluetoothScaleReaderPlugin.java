package com.wisedigits.farmapp;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class BluetoothScaleReaderPlugin implements FlutterPlugin {
    private static final String CHANNEL = "com.wisedigits.farmapp/scale";
    private static final String EVENT_CHANNEL = "com.wisedigits.farmapp/scale/events";
    private static final String TAG = "Gatheru";

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private BluetoothScaleReader scaleReader;
    private SerialService serialService;
    private Context context;
    private boolean serviceBound = false;
    private boolean isBound = false;

    private final ServiceConnection serviceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            SerialService.SerialBinder binder = (SerialService.SerialBinder) service;
            serialService = binder.getService();
            serviceBound = true;
            Log.d(TAG, "SerialService bound");
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            serviceBound = false;
            serialService = null;
            Log.d(TAG, "SerialService unbound");
        }
    };

    // Add custom lifecycle methods
    public void onStop() {
        Log.d(TAG, "BluetoothScaleReaderPlugin onStop");
        stopScaleReader();
    }

    public void onDestroy() {
        Log.d(TAG, "BluetoothScaleReaderPlugin onDestroy");
        teardownChannels();
        if (context != null && isBound) {
            unbindSerialService(context);
        }
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        setupChannels(binding.getBinaryMessenger(), binding.getApplicationContext());
        bindSerialService(binding.getApplicationContext());
    }
//    public void onAttachedToEngine(FlutterPluginBinding binding) {
//        setupChannels(binding.getBinaryMessenger(), binding.getApplicationContext());
//        Intent intent = new Intent(binding.getApplicationContext(), SerialService.class);
//        binding.getApplicationContext().startService(intent);
//        binding.getApplicationContext().bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
//    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        teardownChannels();
        if (serviceBound) {
            binding.getApplicationContext().unbindService(serviceConnection);
            serviceBound = false;
        }
    }

    private void setupChannels(BinaryMessenger messenger, Context context) {
        Log.d(TAG, "Setting up channels");
        this.context = context;

        bindSerialService(context);

        methodChannel = new MethodChannel(messenger, CHANNEL);
        eventChannel = new EventChannel(messenger, EVENT_CHANNEL);

        methodChannel.setMethodCallHandler((call, result) -> {
            Log.d("Gatheru ", "Method call: " + call.method);
            switch (call.method) {
                case "startScaleReader":
                    String deviceAddress = call.argument("deviceAddress");
                    String scaleModel = call.argument("scaleModel");
                    startScaleReader(deviceAddress, scaleModel, result);
                    break;
                case "stopScaleReader":
                    stopScaleReader();
                    result.success(null);
                    break;
                case "getPairedDevices":
                    getPairedDevices(call, result);
                    break;
                case "isBluetoothEnabled":
                    BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
                    result.success(bluetoothAdapter != null && bluetoothAdapter.isEnabled());
                    break;
                default:
                    result.notImplemented();
            }
        });

        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                if (scaleReader == null) {
                    Log.e(TAG, "ScaleReader is null in onListen");
                    events.error("ERROR", "ScaleReader is not initialized", null);
                    return;
                }
                Log.d(TAG, "Stream listening started with arguments: " + arguments);
                scaleReader.setEventSink(events);
            }

            @Override
            public void onCancel(Object arguments) {
                if (scaleReader != null) {
                    scaleReader.setEventSink(null);
                }
                Log.d(TAG, "Stream listening cancelled");
            }
        });
    }

    private void startScaleReader(String deviceAddress, String scaleModel, MethodChannel.Result result) {
        Log.d(TAG, "Starting scale reader for device: " + deviceAddress + ", model: " + scaleModel);
        if (deviceAddress == null || deviceAddress.isEmpty()) {
            Log.e(TAG, "Invalid device address");
            result.error("INVALID_ADDRESS", "Device address is null or empty", null);
            return;
        }

        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not supported");
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth not supported", null);
            return;
        }

        if (!bluetoothAdapter.isEnabled()) {
            Log.e(TAG, "Bluetooth is disabled");
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null);
            return;
        }


        try {
            if (scaleReader != null) {
                Log.d(TAG, "Disconnecting existing scaleReader");
                scaleReader.disconnect();
                scaleReader = null; // Ensure cleanup
            }

            BluetoothDevice device = bluetoothAdapter.getRemoteDevice(deviceAddress); // Fix: Use deviceAddress
            if (device == null) {
                Log.e(TAG, "Device not found: " + deviceAddress);
                result.error("DEVICE_NOT_FOUND", "Device with address " + deviceAddress + " not found", null);
                return;
            }

            scaleReader = new BluetoothScaleReader(context, deviceAddress, scaleModel);
            if (serialService == null) {
                Log.d(TAG, "SerialService not bound, binding and retrying...");
                bindSerialService(context);
                // Wait for binding to complete
                new Handler(Looper.getMainLooper()).postDelayed(() -> {
                    if (serialService != null) {
                        try {
                            serialService.attach(scaleReader);
                            scaleReader.connectAndReadWeight();
                            Log.d(TAG, "ScaleReader initialized and connectAndReadWeight called");
                            result.success(null);
                        } catch (Exception e) {
                            Log.e(TAG, "Failed to attach or connect ScaleReader: " + e.getMessage());
                            result.error("INIT_FAILED", "Failed to initialize ScaleReader: " + e.getMessage(), null);
                        }
                    } else {
                        Log.e(TAG, "SerialService still not bound after retry");
                        result.error("SERVICE_NOT_BOUND", "SerialService not available after retry", null);
                    }
                }, 1000); // Increased to 1000ms for more reliable binding
            } else {
                serialService.attach(scaleReader);
                scaleReader.connectAndReadWeight();
                Log.d(TAG, "ScaleReader initialized and connectAndReadWeight called");
                result.success(null);
            }
        } catch (IllegalArgumentException e) {
            Log.e(TAG, "Invalid device address format: " + deviceAddress, e);
            result.error("INVALID_ADDRESS", "Invalid device address format: " + e.getMessage(), null);
        } catch (SecurityException e) {
            Log.e(TAG, "Bluetooth permission error: " + e.getMessage());
            result.error("PERMISSION_DENIED", "Bluetooth permission error: " + e.getMessage(), null);
        } catch (Exception e) {
            Log.e(TAG, "Failed to initialize ScaleReader: " + e.getMessage());
            result.error("INIT_FAILED", "Failed to initialize ScaleReader: " + e.getMessage(), null);
        }
    }

    private void stopScaleReader() {
        Log.d(TAG, "Stopping scaleReader");
        if (scaleReader != null) {
            try {
                scaleReader.disconnect();
            } catch (Exception e) {
                Log.e(TAG, "Error disconnecting scaleReader: " + e.getMessage(), e);
            }
            scaleReader = null;
        }
        if (serialService != null) {
            try {
                serialService.detach();
                serialService.disconnect();
            } catch (Exception e) {
                Log.e(TAG, "Error detaching/disconnecting serialService: " + e.getMessage(), e);
            }
            serialService = null;
        }
    }

    private void teardownChannels() {
        Log.d(TAG, "Tearing down channels");
        stopScaleReader();
        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
            methodChannel = null;
        }
        if (eventChannel != null) {
            eventChannel.setStreamHandler(null);
            eventChannel = null;
        }
        context = null;
    }

    private void getPairedDevices(MethodCall call, MethodChannel.Result result) {
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not supported");
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth not supported", null);
            return;
        }
        if (!bluetoothAdapter.isEnabled()) {
            Log.e(TAG, "Bluetooth is disabled");
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null);
            return;
        }
        Set<BluetoothDevice> bondedDevices = bluetoothAdapter.getBondedDevices();
        List<Map<String, Object>> devicesList = new ArrayList<>();
        for (BluetoothDevice device : bondedDevices) {
            Map<String, Object> deviceInfo = new HashMap<>();
            deviceInfo.put("name", device.getName() != null ? device.getName() : "Unknown");
            deviceInfo.put("address", device.getAddress());
            deviceInfo.put("model", device.getName() != null ? inferScaleModel(device.getName()) : "default");
            deviceInfo.put("type", device.getType());
            devicesList.add(deviceInfo);
        }
        Log.d(TAG, "Returning paired devices: " + devicesList);
        result.success(devicesList);
    }

    private String inferScaleModel(String deviceName) {
        if (deviceName != null) {
            if (deviceName.contains("YourScale")) return "your_scale_model";
            if (deviceName.contains("AnotherScale")) return "another_scale_model";
        }
        return "default";
    }
    public static void registerWith(BinaryMessenger messenger, Context context) {
        new BluetoothScaleReaderPlugin().setupChannels(messenger, context);
    }


//    private void bindSerialService(Context context) {
//        Intent intent = new Intent(context, SerialService.class);
//        context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
//    }
//    private void unbindSerialService(Context context) {
//        if (isBound) {
//            context.unbindService(serviceConnection);
//            isBound = false;
//            serialService = null;
//        }
//    }

    private void bindSerialService(Context context) {
        Log.d(TAG, "Binding SerialService");
        Intent intent = new Intent(context, SerialService.class);
        isBound = context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
        if (!isBound) {
            Log.e(TAG, "Failed to bind SerialService");
        }
    }
    private void unbindSerialService(Context context) {
        if (isBound && serviceBound) {
            Log.d(TAG, "Unbinding SerialService");
            try {
                context.unbindService(serviceConnection);
            } catch (Exception e) {
                Log.e(TAG, "Error unbinding SerialService: " + e.getMessage(), e);
            }
            isBound = false;
            serviceBound = false;
            serialService = null;
        }
    }
}