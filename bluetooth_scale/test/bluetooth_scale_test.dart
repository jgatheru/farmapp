import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_scale/bluetooth_scale.dart';
import 'package:bluetooth_scale/bluetooth_scale_platform_interface.dart';
import 'package:bluetooth_scale/bluetooth_scale_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBluetoothScalePlatform
    with MockPlatformInterfaceMixin
    implements BluetoothScalePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BluetoothScalePlatform initialPlatform = BluetoothScalePlatform.instance;

  test('$MethodChannelBluetoothScale is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBluetoothScale>());
  });

  test('getPlatformVersion', () async {
    BluetoothScale bluetoothScalePlugin = BluetoothScale();
    MockBluetoothScalePlatform fakePlatform = MockBluetoothScalePlatform();
    BluetoothScalePlatform.instance = fakePlatform;

    expect(await bluetoothScalePlugin.getPlatformVersion(), '42');
  });
}
