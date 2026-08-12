/// 考试类别（如考研英语）。
class EssayExam {
  final String id;
  final String name;
  final String description;
  final List<EssayTopic> topics;

  const EssayExam({
    required this.id,
    required this.name,
    required this.description,
    required this.topics,
  });
}

/// 作文题材（如图画作文、议论文）。
class EssayTopic {
  final String id;
  final String name;
  final String description;
  final List<String> practicePrompts; // 写作练习题目

  const EssayTopic({
    required this.id,
    required this.name,
    required this.description,
    required this.practicePrompts,
  });
}

/// 模板中的一个部分（如「开头段 · 描述图画」）。
class TemplatePart {
  final String name;
  final List<String> sentences; // 可选的句式

  const TemplatePart({required this.name, required this.sentences});
}

/// 题材作文模板。
class EssayTemplate {
  final String title;
  final List<TemplatePart> parts;
  final String fullTemplate;

  const EssayTemplate({
    required this.title,
    required this.parts,
    required this.fullTemplate,
  });
}

/// 范文。
class EssaySample {
  final String title;
  final String prompt;
  final String essay;
  final String translation;
  final String comment;

  const EssaySample({
    required this.title,
    required this.prompt,
    required this.essay,
    required this.translation,
    required this.comment,
  });
}

/// 句式分类（如「开头引入」）。
class SentenceCategory {
  final String name;
  final List<String> sentences;

  const SentenceCategory({required this.name, required this.sentences});
}

/// 用户写作草稿（本地保存）。
class EssayDraft {
  final int id;
  final String examId;
  final String topicId;
  final String prompt;
  final String content;
  final int wordCount;
  final DateTime createdAt;

  const EssayDraft({
    required this.id,
    required this.examId,
    required this.topicId,
    required this.prompt,
    required this.content,
    required this.wordCount,
    required this.createdAt,
  });

  factory EssayDraft.fromMap(Map<String, dynamic> map) => EssayDraft(
        id: map['id'] as int,
        examId: map['exam_id'] as String,
        topicId: map['topic_id'] as String,
        prompt: map['prompt'] as String,
        content: map['content'] as String,
        wordCount: map['word_count'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'exam_id': examId,
        'topic_id': topicId,
        'prompt': prompt,
        'content': content,
        'word_count': wordCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
