import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bluetooth_scale_platform_interface.dart';

/// An implementation of [BluetoothScalePlatform] that uses method channels.
class MethodChannelBluetoothScale extends BluetoothScalePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bluetooth_scale');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
