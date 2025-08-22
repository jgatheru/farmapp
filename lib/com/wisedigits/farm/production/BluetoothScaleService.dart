import 'dart:async';
import 'package:flutter/services.dart';

class BluetoothScaleService {
  static final BluetoothScaleService _instance = BluetoothScaleService._internal();
  factory BluetoothScaleService() => _instance;
  BluetoothScaleService._internal();

  static const platform = MethodChannel('com.wisedigits.farmapp/scale');
  static const eventChannel = EventChannel('com.wisedigits.farmapp/scale/events');

  StreamSubscription<dynamic>? _weightSubscription;
  bool _isListenerActive = false;
  bool _isScaleConnected = false;
  final StreamController<double> _weightController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();

  Stream<double> get weightStream => _weightController.stream;
  Stream<String> get errorStream => _errorController.stream;

  Future<void> startScaleReader(String deviceAddress, {String scaleModel = 'default'}) async {
    double weight=0.0;
    try {
      await _stopListener();
      await platform.invokeMethod('startScaleReader', {
        'deviceAddress': deviceAddress,
        'scaleModel': scaleModel,
      });


      _weightSubscription = eventChannel.receiveBroadcastStream().listen(
            (event) {

          print('Gatheru Received event: $event, type: ${event.runtimeType}');
          try {
            if (event is String && event == "Connected") {
              _isScaleConnected = true;
              print('Gatheru Scale connected');
              return;
            }

            if (event is double) {
              weight = event;
            } else if (event is num) {
              weight = event.toDouble();
            } else {
              throw FormatException('Invalid weight format: $event');
            }
            print('Gatheru Parsed weight: $weight');
            if (!_weightController.isClosed) {

            }
          } catch (e) {
            print('Gatheru Error parsing weight: $e');
            if (!_errorController.isClosed) {
              _errorController.add('Invalid weight data: $e');
            }
          }
        },
        onError: (error) {
          print('Gatheru EventChannel error: $error');
          if (!_errorController.isClosed) {
            String errorMessage = error.toString();
            if (errorMessage.contains('Connection error')) {
              errorMessage = 'Failed to connect to scale. Ensure it is powered on and in range.';
            }
            _errorController.add(errorMessage);
          }
          _isScaleConnected = false;
        },
        onDone: () {
          print('Gatheru EventChannel stream closed');
          if (!_errorController.isClosed) {
            _errorController.add('Bluetooth stream closed');
          }
          _isListenerActive = false;
          _isScaleConnected = false;
        },
      );
      _isListenerActive = true;
      print('Gatheru Started scale reader for $deviceAddress, model: $scaleModel');
    } catch (e) {
      print('Gatheru Error starting scale reader: $e');
      if (!_errorController.isClosed) {
        _errorController.add('Error starting scale reader: $e');
      }
      _isScaleConnected = false;
      rethrow;
    }
    _weightController.add(weight);
  }

  Future<void> stopScaleReader() async {
    try {
      await platform.invokeMethod('stopScaleReader');
      await _stopListener();
      _isScaleConnected = false;
      print('Gatheru Stopped scale reader');
    } catch (e) {
      print('Gatheru Error stopping scale reader: $e');
      if (!_errorController.isClosed) {
        _errorController.add('Error stopping scale reader: $e');
      }
    }
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      return await platform.invokeMethod('isBluetoothEnabled');
    } catch (e) {
      print('Gatheru Error checking Bluetooth: $e');
      if (!_errorController.isClosed) {
        _errorController.add('Error checking Bluetooth: $e');
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    try {
      final List<dynamic> devices = await platform.invokeMethod('getPairedDevices');
      return devices.map((device) {
        final map = device as Map;
        return {
          'name': map['name']?.toString() ?? 'Unknown Device',
          'address': map['address']?.toString() ?? '',
          'model': map['model']?.toString() ?? 'default',
          'type': map['type']?.toString() ?? '0',
        };
      }).toList();
    } catch (e) {
      print('Gatheru Error getting paired devices: $e');
      if (!_errorController.isClosed) {
        _errorController.add('Error getting paired devices: $e');
      }
      rethrow;
    }
  }

  Future<void> _stopListener() async {
    if (_weightSubscription != null) {
      await _weightSubscription?.cancel();
      _weightSubscription = null;
      _isListenerActive = false;
    }
  }

  bool get isScaleConnected => _isScaleConnected;

  void dispose() {
    print('Gatheru Disposing BluetoothScaleService...');
    _stopListener();
    if (!_weightController.isClosed) {
      _weightController.close();
    }
    if (!_errorController.isClosed) {
      _errorController.close();
    }
  }
}