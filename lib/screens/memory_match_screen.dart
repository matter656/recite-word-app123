import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../games/memory_match_game.dart';
import '../providers/app_providers.dart';

/// 记忆翻牌：翻两张牌，单词与释义配对消除。
class MemoryMatchScreen extends ConsumerStatefulWidget {
  final String bookId;
  const MemoryMatchScreen({super.key, required this.bookId});

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
  MemoryMatchGame? _game;
  bool _loading = true;
  String? _error;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _done = false;
      _elapsed = Duration.zero;
    });
    _timer?.cancel();
    try {
      final words = await ref
          .read(wordBookRepositoryProvider)
          .getWords(widget.bookId);
      if (!mounted) return;
      setState(() {
        _game = MemoryMatchGame(words);
        _loading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _flip(MatchCard card) {
    final game = _game;
    if (game == null || _done || game.isMatched(card.id)) return;

    setState(() {
      final outcome = game.flip(card.id);
      if (outcome == FlipOutcome.mismatch) {
        // 短暂展示两张牌后翻回
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() => game.unlockAll());
        });
      } else if (outcome == FlipOutcome.done) {
        _timer?.cancel();
        _done = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记忆翻牌')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败：$_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final game = _game!;
    if (_done) {
      return _ResultView(
        attempts: game.attempts,
        elapsed: _elapsed,
        onReplay: _load,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text('${_elapsed.inSeconds} 秒',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('翻牌 ${game.attempts} 次',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [for (final card in game.cards) _cardWidget(game, card)],
          ),
        ),
      ],
    );
  }

  Widget _cardWidget(MemoryMatchGame game, MatchCard card) {
    // 已配对 / 当前翻开 / 判定锁定中（短暂展示）都显示正面
    final faceUp = game.isMatched(card.id) ||
        game.flipped.contains(card.id) ||
        game.isLocked(card.id);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _flip(card),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: faceUp
            ? Container(
                key: ValueKey('up-${card.id}'),
                decoration: BoxDecoration(
                  color: game.isMatched(card.id)
                      ? Colors.green.shade100
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(6),
                alignment: Alignment.center,
                child: Text(
                  card.isWord ? card.text : card.text,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: card.isWord ? 16 : 12,
                    fontWeight:
                        card.isWord ? FontWeight.bold : FontWeight.normal,
                    color: card.isWord
                        ? scheme.onPrimaryContainer
                        : Colors.black87,
                  ),
                ),
              )
            : Container(
                key: ValueKey('down-${card.id}'),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.question_mark, color: scheme.onPrimary),
              ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final int attempts;
  final Duration elapsed;
  final VoidCallback onReplay;

  const _ResultView({
    required this.attempts,
    required this.elapsed,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, size: 72, color: Colors.amber.shade600),
          const SizedBox(height: 16),
          Text('全部配对成功！', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text('翻牌 $attempts 次', style: theme.textTheme.titleLarge),
          Text('用时 ${elapsed.inSeconds} 秒',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay),
                label: const Text('再来一局'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
