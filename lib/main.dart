import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    } catch (e) {
      if (!mounted) return;
      _lastError = '$e';
      setState(() => _status = _BootstrapStatus.error);
    }
  }

  String _lastError = '';

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
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('初始化失败'),
                const SizedBox(height: 8),
                Text(_lastError, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                FilledButton(onPressed: _bootstrap, child: const Text('重试')),
              ],
            ),
          ),
        );
      case _BootstrapStatus.done:
        return const HomeScreen();
    }
  }
}
