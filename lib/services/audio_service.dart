import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 单词在线真人发音（有道词典音源，国内可访问）。
/// 不依赖手机 TTS，稳定可靠；需要网络。
class WordAudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放单词真人发音（美式）。返回是否已开始播放。
  static Future<bool> play(String word) async {
    final url = 'https://dict.youdao.com/dictvoice'
        '?audio=${Uri.encodeComponent(word.trim())}&type=2';
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() => _player.stop();
}

/// 句子/短文在线发音（百度翻译 TTS，国内可访问、免费、支持长文本）。
class SentenceAudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放句子/短文发音（英文）。返回是否已开始播放。
  static Future<bool> play(String text) async {
    final url = 'https://fanyi.baidu.com/gettts'
        '?lan=en&text=${Uri.encodeComponent(text.trim())}&spd=3&source=web';
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() => _player.stop();
}

/// TTS 朗读服务：调用 Android 原生 TextToSpeech（绕开 flutter_tts 兼容问题）。
class TtsService {
  static const _channel = MethodChannel('vocab_app/tts');
  static bool _available = true;
  static bool _inited = false;

  /// 初始化原生 TTS 引擎（每次播放重新检测，用户可能切换引擎）。
  static Future<void> init() async {
    _available = true;
    _inited = true;
    try {
      _available = await _channel.invokeMethod<bool>('init') ?? false;
    } catch (_) {
      _available = false;
    }
  }

  /// 朗读文本；返回是否成功。
  static Future<bool> speak(String text) async {
    if (!_inited) await init();
    if (!_available) return false;
    try {
      return await _channel.invokeMethod<bool>('speak', {'text': text}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
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
