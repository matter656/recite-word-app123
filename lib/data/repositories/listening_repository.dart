import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/listening.dart';

/// 听力模块数据访问层：加载短文材料。
class ListeningRepository {
  List<ListeningArticle>? _cache;

  Future<List<ListeningArticle>> getArticles() async {
    _cache ??= _parse(
        await rootBundle.loadString('assets/listening/short_articles.json'));
    return _cache!;
  }

  static List<ListeningArticle> _parse(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return [
      for (final a in data['articles'] as List)
        ListeningArticle(
          id: a['id'] as String,
          title: a['title'] as String,
          level: a['level'] as String,
          topic: a['topic'] as String,
          text: a['text'] as String,
          questions: [
            for (final q in a['questions'] as List)
              _parseQuestion(q as Map<String, dynamic>),
          ],
        ),
    ];
  }

  static ListeningQuestion _parseQuestion(Map<String, dynamic> q) {
    final type = q['type'] as String;
    final options = [
      for (final o in (q['options'] as List? ?? const [])) o as String,
    ];
    final rawAnswer = q['answer'];
    // choice: answer 存的是正确选项索引；blank: answer 是答案词
    final answer = type == 'choice'
        ? options[rawAnswer as int]
        : rawAnswer as String;
    return ListeningQuestion(
      type: type,
      question: q['question'] as String,
      options: options,
      answer: answer,
    );
  }
}
