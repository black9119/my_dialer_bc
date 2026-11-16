import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoManager {
  static final ZegoManager _instance = ZegoManager._internal();
  factory ZegoManager() => _instance;
  ZegoManager._internal();

  // TODO: 请替换为你真实的 ZEGO 配置
  static const int appID = 491443522;
  static const String appSign =
      "f141828e865741eb46cccf86fb4667b5d808e4e02be0f214dcdcfbe622db4204";

  // 固定房间号，B 和 C 都用这个
  static const String fixedRoomId = "fixed_room_888888";

  bool _isInRoom = false;

  Future<void> initAndLogin() async {
    if (_isInRoom) return;
    ZegoEngineProfile profile =
        ZegoEngineProfile(appID, ZegoScenario.Default, appSign: appSign);
    await ZegoExpressEngine.createEngineWithProfile(profile);

    // 登录房间
    ZegoUser user =
        ZegoUser.id("user_${DateTime.now().millisecondsSinceEpoch}");
    await ZegoExpressEngine.instance.loginRoom(fixedRoomId, user);

    // 推拉流 (用于变声和接收 C 端语音)
    await ZegoExpressEngine.instance
        .startPublishingStream("stream_$fixedRoomId");
    await ZegoExpressEngine.instance.startPlayingStream("stream_$fixedRoomId");

    _isInRoom = true;
  }

  // 开启/关闭免提外放
  Future<void> enableSpeaker(bool enable) async {
    await ZegoExpressEngine.instance.muteSpeaker(!enable);
  }
}
