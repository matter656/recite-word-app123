import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/essay.dart';
import '../app_database.dart';

/// 作文模块数据访问层：加载内置内容（题材/模板/范文/句式）+ 草稿 CRUD。
class EssayRepository {
  final AppDatabase _db;

  EssayRepository(this._db);

  // ---- 内置内容加载（按需缓存）----

  List<EssayExam>? _examsCache;
  Map<String, EssayTemplate>? _templatesCache;
  Map<String, List<EssaySample>>? _samplesCache;
  List<SentenceCategory>? _sentencesCache;

  Future<List<EssayExam>> getExams() async {
    _examsCache ??= _parseExams(
        await rootBundle.loadString('assets/essays/topics.json'));
    return _examsCache!;
  }

  Future<EssayTemplate> getTemplate(String topicId) async {
    _templatesCache ??= _parseTemplates(
        await rootBundle.loadString('assets/essays/templates.json'));
    final t = _templatesCache![topicId];
    if (t == null) throw StateError('模板不存在: $topicId');
    return t;
  }

  Future<List<EssaySample>> getSamples(String topicId) async {
    _samplesCache ??= _parseSamples(
        await rootBundle.loadString('assets/essays/samples.json'));
    return _samplesCache![topicId] ?? const [];
  }

  Future<List<SentenceCategory>> getSentenceCategories() async {
    _sentencesCache ??= _parseSentences(
        await rootBundle.loadString('assets/essays/sentences.json'));
    return _sentencesCache!;
  }

  static List<EssayExam> _parseExams(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return [
      for (final e in data['exams'] as List)
        EssayExam(
          id: e['id'] as String,
          name: e['name'] as String,
          description: e['description'] as String,
          topics: [
            for (final t in e['topics'] as List)
              EssayTopic(
                id: t['id'] as String,
                name: t['name'] as String,
                description: t['description'] as String,
                practicePrompts: [
                  for (final p in t['practicePrompts'] as List) p as String,
                ],
              ),
          ],
        ),
    ];
  }

  static Map<String, EssayTemplate> _parseTemplates(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return {
      for (final entry in data.entries)
        entry.key: EssayTemplate(
          title: entry.value['title'] as String,
          parts: [
            for (final p in entry.value['parts'] as List)
              TemplatePart(
                name: p['name'] as String,
                sentences: [
                  for (final s in p['sentences'] as List) s as String,
                ],
              ),
          ],
          fullTemplate: entry.value['fullTemplate'] as String,
        ),
    };
  }

  static Map<String, List<EssaySample>> _parseSamples(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return {
      for (final entry in data.entries)
        entry.key: [
          for (final s in entry.value as List)
            EssaySample(
              title: s['title'] as String,
              prompt: s['prompt'] as String,
              essay: s['essay'] as String,
              translation: s['translation'] as String,
              comment: s['comment'] as String,
            ),
        ],
    };
  }

  static List<SentenceCategory> _parseSentences(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return [
      for (final c in data['categories'] as List)
        SentenceCategory(
          name: c['name'] as String,
          sentences: [
            for (final s in c['sentences'] as List) s as String,
          ],
        ),
    ];
  }

  // ---- 写作草稿 CRUD ----

  /// 保存草稿，返回新 id。
  Future<int> saveDraft(EssayDraft draft) async {
    final db = await _db.database;
    final map = draft.toMap();
    map.remove('id'); // 由自增生成
    return db.insert('essay_drafts', map);
  }

  Future<List<EssayDraft>> getDrafts() async {
    final db = await _db.database;
    final rows = await db.query('essay_drafts', orderBy: 'created_at DESC');
    return rows.map(EssayDraft.fromMap).toList();
  }

  Future<void> deleteDraft(int id) async {
    final db = await _db.database;
    await db.delete('essay_drafts', where: 'id = ?', whereArgs: [id]);
  }

  /// 英文单词数统计（按空白分词）。
  static int countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }
}
