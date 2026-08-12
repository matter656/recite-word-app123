import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// TTS 朗读服务（手机系统文字转语音，离线）。
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _available = true; // 是否有可用的英文语音引擎

  /// 每次调用重新检测引擎（用户可能中途安装/切换语音引擎）。
  static Future<void> init() async {
    _available = true;
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    try {
      // 优先使用 Google TTS（英文支持最稳，用户可能刚安装）
      try {
        await _tts.setEngine('com.google.android.tts');
      } catch (_) {
        // 未安装 Google TTS 时忽略，使用系统默认引擎
      }
      final langs = await _tts.getLanguages;
      if (langs != null && langs.isNotEmpty) {
        if (langs.contains('en-US')) {
          await _tts.setLanguage('en-US');
        } else if (langs.contains('en')) {
          await _tts.setLanguage('en');
        } else if (langs.any((l) => l.startsWith('en'))) {
          await _tts
              .setLanguage(langs.firstWhere((l) => l.startsWith('en')));
        } else {
          _available = false; // 没有英文语音引擎
        }
      } else {
        await _tts.setLanguage('en-US');
      }
    } catch (_) {
      _available = false;
    }
  }

  /// 朗读文本；返回是否成功（引擎不可用或朗读失败返回 false）。
  static Future<bool> speak(String text) async {
    await init();
    if (!_available) return false;
    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      return result == 1;
    } catch (_) {
      return false;
    }
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
