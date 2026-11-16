import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BleService {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  // 收到 A 端指令的回调
  Function(String command)? onCommandReceived;

  Future<void> startBroadcasting() async {
    try {
      // 监听数据接收，使用 dynamic 动态接收，避免类型不匹配报错
      _peripheral.onDataReceived.listen((dynamic event) {
        if (onCommandReceived != null) {
          // 尝试安全地解析数据
          try {
            // 很多时候 event 本身就是字节数组，或者 event.data 是字节数组
            // 这里做兼容处理
            final List<int> bytes = event is List<int> ? event : event.data;
            onCommandReceived!(String.fromCharCodes(bytes));
          } catch (e) {
            print("数据解析失败: $e");
          }
        }
      });

      // 开启广播
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
