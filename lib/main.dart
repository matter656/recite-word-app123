import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'screens/main_shell.dart';
import 'services/error_reporter.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorReporter.init();
  await NotificationService.init();
  runApp(const ProviderScope(child: VocabApp()));
}

class VocabApp extends StatelessWidget {
  const VocabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '背单词',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BootstrapScreen(),
    );
  }
}

/// 启动页：首次运行导入内置词库，完成后进入首页。
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

enum _BootstrapStatus { loading, error, done }

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  _BootstrapStatus _status = _BootstrapStatus.loading;
  String _lastError = '';
  String _lastStack = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _status = _BootstrapStatus.loading);
    final repo = ref.read(wordBookRepositoryProvider);
    try {
      if (!await repo.isImported()) {
        await repo.importWordBooks(const ['cet4', 'cet6', 'ky', 'ielts']);
      }
      if (!mounted) return;
      ref.invalidate(booksProvider);
      setState(() => _status = _BootstrapStatus.done);
    } catch (e, s) {
      if (!mounted) return;
      _lastError = '$e';
      _lastStack = '$s';
      setState(() => _status = _BootstrapStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _BootstrapStatus.loading:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在准备词库…'),
              ],
            ),
          ),
        );
      case _BootstrapStatus.error:
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Icon(Icons.error_outline,
                      size: 56, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  Text('初始化失败',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SelectableText(
                    _lastError,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (_lastStack.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _lastStack,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _bootstrap, child: const Text('重试')),
                ],
              ),
            ),
          ),
        );
      case _BootstrapStatus.done:
        return const MainShell();
    }
  }
}
