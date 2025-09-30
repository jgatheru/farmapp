package com.wisedigits.farmapp;

import android.content.Context;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    private BluetoothScaleReaderPlugin bluetoothPlugin;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
//        GeneratedPluginRegistrant.registerWith(flutterEngine);
        // Manually register if needed
        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
        Context context = getApplicationContext();
        new BluetoothScaleReaderPlugin().registerWith(messenger,context);
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (bluetoothPlugin != null) {
            bluetoothPlugin.onStop();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (bluetoothPlugin != null) {
            bluetoothPlugin.onDestroy();
            bluetoothPlugin = null;
        }
    }
}