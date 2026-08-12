/// 学习记录（供统计与打卡使用，每词每次自评一条）。
class StudyLog {
  final int id;
  final String date; // yyyy-MM-dd
  final int wordId;
  final int rating; // 0=忘了 1=模糊 2=记得
  final DateTime reviewedAt;

  const StudyLog({
    required this.id,
    required this.date,
    required this.wordId,
    required this.rating,
    required this.reviewedAt,
  });

  factory StudyLog.fromMap(Map<String, dynamic> map) => StudyLog(
        id: map['id'] as int,
        date: map['date'] as String,
        wordId: map['word_id'] as int,
        rating: map['rating'] as int,
        reviewedAt:
            DateTime.fromMillisecondsSinceEpoch(map['reviewed_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'word_id': wordId,
        'rating': rating,
        'reviewed_at': reviewedAt.millisecondsSinceEpoch,
      };
}
