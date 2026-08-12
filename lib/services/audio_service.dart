import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// TTS 朗读服务（手机系统文字转语音，离线）。
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    _inited = true;
  }

  static Future<void> speak(String text) async {
    await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> stop() => _tts.stop();
}

/// 录音与回放服务（跟读对比用）。
class RecorderService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static String? _filePath;

  /// 是否有录音权限。
  static Future<bool> hasPermission() =>
      _recorder.hasPermission();

  /// 开始录音。
  static Future<void> start() async {
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _filePath!,
    );
  }

  /// 停止录音，返回音频文件路径。
  static Future<String?> stop() async {
    final path = await _recorder.stop();
    _filePath = null;
    return path;
  }

  /// 播放录音文件。
  static Future<void> playFile(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  static Future<void> stopPlayback() => _player.stop();

  static Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
