import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'bluetooth_scale_method_channel.dart';

abstract class BluetoothScalePlatform extends PlatformInterface {
  /// Constructs a BluetoothScalePlatform.
  BluetoothScalePlatform() : super(token: _token);

  static final Object _token = Object();

  static BluetoothScalePlatform _instance = MethodChannelBluetoothScale();

  /// The default instance of [BluetoothScalePlatform] to use.
  ///
  /// Defaults to [MethodChannelBluetoothScale].
  static BluetoothScalePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BluetoothScalePlatform] when
  /// they register themselves.
  static set instance(BluetoothScalePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
