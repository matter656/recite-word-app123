import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局错误捕获：把未处理异常写入日志文件，便于定位真机问题。
class ErrorReporter {
  static String? _logPath;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logPath = '${dir.path}/error_log.txt';

    FlutterError.onError = (details) {
      _write('${details.exception}');
      _write('${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _write('$error');
      _write('$stack');
      return true;
    };
  }

  static void _write(String text) {
    final path = _logPath;
    if (path == null) return;
    try {
      final file = File(path);
      file.writeAsStringSync(
        '\n[${DateTime.now()}] $text\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // 日志写入失败不影响主流程
    }
  }

  /// 读取日志内容（供错误页展示/导出）。
  static Future<String?> readLog() async {
    final path = _logPath;
    if (path == null || !File(path).existsSync()) return null;
    return File(path).readAsString();
  }
}
