import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BleService {
  static final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  // 收到 A 端指令的回调
  Function(String command)? onCommandReceived;

  Future<void> startBroadcasting() async {
    try {
      _peripheral.onDataReceived.listen((event) {
        if (onCommandReceived != null) {
          onCommandReceived!(String.fromCharCodes(event.data));
        }
      });

      await _peripheral.start(
        advertiseData: const AdvertiseDataCore(
          localName: "MyDialer_BC",
          serviceUuid: "0000ffe0-0000-1000-8000-00805f9b34fb",
        ),
        gattServer: const GattServerSettings(),
      );
      print("B端广播已开启");
    } catch (e) {
      print("广播失败: $e");
    }
  }
}
