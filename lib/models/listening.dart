/// 听力短文模型。
class ListeningArticle {
  final String id;
  final String title;
  final String level; // 入门/初级/中级
  final String topic;
  final String text; // 正文（TTS 朗读）
  final List<ListeningQuestion> questions;

  const ListeningArticle({
    required this.id,
    required this.title,
    required this.level,
    required this.topic,
    required this.text,
    required this.questions,
  });
}

/// 听力题目：选择题或填空题。
class ListeningQuestion {
  final String type; // choice | blank
  final String question;
  final List<String> options; // choice 类型为 4 个选项，blank 为空
  final String answer; // choice: 正确选项文本；blank: 答案词

  const ListeningQuestion({
    required this.type,
    required this.question,
    this.options = const [],
    required this.answer,
  });

  bool isChoice() => type == 'choice';
}
