import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service.dart';
import 'zego_manager.dart';
import 'dart:async';
import 'dart:convert';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  int _currentIndex = 3;
  String _inputNumber = '';
  String _role = '未分配';

  bool _isCalling = false;
  int _callSeconds = 0;
  Timer? _callTimer;
  bool _isSpeakerOn = false;

  List<Map<String, dynamic>> _callRecords = [];

  final BleService _bleService = BleService();
  final ZegoManager _zegoManager = ZegoManager();

  final Map<String, String> _letters = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+'
  };

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadRole();

    // 监听 A 端发来的 BLE 指令
    _bleService.onCommandReceived = (command) {
      if (_role == 'B' && !_isCalling) {
        _startOutgoingCall('10086');
      }
    };
  }

  Future<void> _loadRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String role = prefs.getString('device_role') ?? '未分配';
    setState(() => _role = role);

    if (role == 'B') {
      try {
        await _bleService.startBroadcasting();
      } catch (e) {
        _showError("蓝牙启动失败: $e");
      }
    }
  }

  Future<void> _loadRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? recordsStr = prefs.getString('call_records');
    if (recordsStr != null) {
      setState(() {
        _callRecords = (jsonDecode(recordsStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  Future<void> _saveRecord(String number, int duration) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String time = TimeOfDay.now().format(context);
    _callRecords
        .insert(0, {'number': number, 'time': time, 'duration': duration});
    await prefs.setString('call_records', jsonEncode(_callRecords));
    setState(() {});
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _startOutgoingCall(String number) async {
    setState(() {
      _isCalling = true;
      _inputNumber = number;
      _callSeconds = 0;
      _isSpeakerOn = false;
    });

    // 尝试连接 ZEGO 房间
    try {
      await _zegoManager.initAndLogin();
    } catch (e) {
      _showError("语音连接失败，请检查 ZEGO 配置");
    }

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _callSeconds++);
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    if (_callSeconds > 0) {
      _saveRecord(_inputNumber, _callSeconds);
    }
    setState(() {
      _isCalling = false;
      _inputNumber = '';
    });
  }

  void _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    try {
      await _zegoManager.enableSpeaker(_isSpeakerOn);
    } catch (e) {
      _showError("外放切换失败");
    }
  }

  void _onNumberPress(String num) {
    setState(() => _inputNumber += num);
    if (_inputNumber == '999999999') {
      _inputNumber = '';
      Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()))
          .then((_) => _loadRole());
    }
  }

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? Colors.black : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color keyBgColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFE5E5EA);
    Color borderColor = isDark ? Colors.white12 : Colors.black12;

    Color callBgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color callBtnBgColor =
        isDark ? Colors.white.withOpacity(0.15) : const Color(0xFFE5E5EA);
    Color callBtnIconColor = isDark ? Colors.white : Colors.black;
    Color callSubTextColor = isDark ? Colors.white70 : Colors.black54;

    if (_isCalling) {
      return Scaffold(
        backgroundColor: callBgColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(_callSeconds < 3 ? '正在呼叫...' : _formatDuration(_callSeconds),
                  style: TextStyle(
                      color: textColor.withOpacity(0.6), fontSize: 16)),
              const SizedBox(height: 10),
              Text(_inputNumber,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 44,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _toggleSpeaker,
                    child: _buildActionIcon(
                        Icons.volume_up,
                        _isSpeakerOn ? '外放中' : '免提',
                        _isSpeakerOn ? Colors.white : callBtnBgColor,
                        _isSpeakerOn ? Colors.black : callBtnIconColor,
                        callSubTextColor),
                  ),
                  _buildActionIcon(Icons.videocam, 'FaceTime 通话',
                      callBtnBgColor, callBtnIconColor, callSubTextColor),
                  _buildActionIcon(Icons.mic_off, '静音', callBtnBgColor,
                      callBtnIconColor, callSubTextColor),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionIcon(Icons.person_add_alt_1, '添加', callBtnBgColor,
                      callBtnIconColor, callSubTextColor),
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30), shape: BoxShape.circle),
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 36),
                    ),
                  ),
                  _buildActionIcon(Icons.dialpad, '拨号键盘', callBtnBgColor,
                      callBtnIconColor, callSubTextColor),
                ],
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildPlaceholderTab('个人收藏', Icons.star_border, textColor, bgColor),
            _buildRecentTab(textColor, bgColor),
            _buildPlaceholderTab(
                '通讯录', Icons.person_outline, textColor, bgColor),
            _buildDialerTab(textColor, keyBgColor, textColor),
            _buildPlaceholderTab('语音留言', Icons.voicemail, textColor, bgColor),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark, borderColor, textColor),
    );
  }

  Widget _buildRecentTab(Color textColor, Color bgColor) {
    if (_callRecords.isEmpty)
      return Center(
          child: Text('无通话记录',
              style: TextStyle(color: textColor.withOpacity(0.5))));
    return ListView.separated(
      itemCount: _callRecords.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = _callRecords[index];
        return ListTile(
          leading: Icon(Icons.call_made, color: textColor.withOpacity(0.6)),
          title: Text(record['number'],
              style: TextStyle(color: textColor, fontSize: 18)),
          subtitle: Text('${record['time']} · 免提外放',
              style:
                  TextStyle(color: textColor.withOpacity(0.5), fontSize: 13)),
          trailing: Text(_formatDuration(record['duration']),
              style: TextStyle(color: textColor.withOpacity(0.5))),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Color bgColor,
      Color iconColor, Color textColor) {
    return Column(
      children: [
        Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 30)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: textColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildBottomNavBar(bool isDark, Color borderColor, Color textColor) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          border: Border(top: BorderSide(color: borderColor, width: 0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.star_border, Icons.star, '个人收藏'),
          _buildNavItem(1, Icons.access_time, Icons.access_time_filled, '最近通话'),
          _buildNavItem(2, Icons.person_outline, Icons.person, '通讯录'),
          _buildNavItem(3, Icons.dialpad, Icons.dialpad, '拨号键盘'),
          _buildNavItem(4, Icons.voicemail, Icons.voicemail, '语音留言'),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF0A84FF) : Colors.grey,
              size: 26),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isActive ? const Color(0xFF0A84FF) : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(
      String title, IconData icon, Color textColor, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
          title: Text(title),
          backgroundColor: bgColor,
          elevation: 0,
          foregroundColor: textColor),
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 60, color: Colors.grey[600]),
        const SizedBox(height: 10),
        Text('暂无$title',
            style: const TextStyle(color: Colors.grey, fontSize: 16)),
      ])),
    );
  }

  Widget _buildDialerTab(
      Color textColor, Color keyBgColor, Color keyTextColor) {
    return Column(
      children: [
        Expanded(
            flex: 1,
            child: Center(
                child: Text(_inputNumber,
                    style: TextStyle(
                        fontSize: 40, color: textColor, letterSpacing: 2)))),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRow(['1', '2', '3'], keyBgColor, keyTextColor),
                _buildRow(['4', '5', '6'], keyBgColor, keyTextColor),
                _buildRow(['7', '8', '9'], keyBgColor, keyTextColor),
                _buildRow(['*', '0', '#'], keyBgColor, keyTextColor),
              ],
            ),
          ),
        ),
        Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 70),
              GestureDetector(
                onTap: () {
                  if (_inputNumber.isNotEmpty && _role == 'B') {
                    _startOutgoingCall(_inputNumber);
                  }
                },
                child: Container(
                    width: 75,
                    height: 75,
                    decoration: const BoxDecoration(
                        color: Color(0xFF34C759), shape: BoxShape.circle),
                    child:
                        const Icon(Icons.call, color: Colors.white, size: 34)),
              ),
              GestureDetector(
                onTap: () {
                  if (_inputNumber.isNotEmpty) {
                    setState(() => _inputNumber =
                        _inputNumber.substring(0, _inputNumber.length - 1));
                  }
                },
                child: Container(
                    width: 70,
                    alignment: Alignment.center,
                    child: _inputNumber.isNotEmpty
                        ? Icon(Icons.backspace_outlined,
                            color: textColor, size: 28)
                        : const SizedBox()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRow(List<String> keys, Color bgColor, Color textColor) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key, bgColor, textColor)).toList());

  Widget _buildKey(String key, Color bgColor, Color textColor) {
    String letter = _letters[key] ?? '';
    return GestureDetector(
      onTap: () => _onNumberPress(key),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(key,
                style: TextStyle(
                    fontSize: 34,
                    color: textColor,
                    fontWeight: FontWeight.w300)),
            if (letter.isNotEmpty)
              Text(letter,
                  style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

// 隐藏设置页
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _role = '未分配';
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() => _role = prefs.getString('device_role') ?? '未分配');
    });
  }

  Future<void> _setRole(String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_role', role);
    setState(() => _role = role);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已选为 $role 端')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐藏设置页')),
      body: ListView(
        children: [
          ListTile(
              title: const Text('当前角色'),
              subtitle: Text(_role,
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold))),
          const Divider(),
          ListTile(
              title: const Text('选为 A 端 (安卓控制端)'), onTap: () => _setRole('A')),
          ListTile(
              title: const Text('选为 B 端 (苹果执行端)'), onTap: () => _setRole('B')),
        ],
      ),
    );
  }
}
