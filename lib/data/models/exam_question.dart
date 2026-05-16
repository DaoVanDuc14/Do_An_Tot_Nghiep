import 'package:cloud_firestore/cloud_firestore.dart';

/// Loại câu hỏi trong đề thi
enum ExamQuestionType { pronunciation, mcq }

/// Model cho collection [exam_questions] trên Firestore.
class ExamQuestion {
  final String id;
  final String examPaperId;
  final ExamQuestionType type;
  final String targetText;
  final List<String> options; // 4 lựa chọn (chỉ MCQ)
  final String correctAnswer; // Đáp án đúng (chỉ MCQ)
  final int orderIndex;

  ExamQuestion({
    required this.id,
    required this.examPaperId,
    required this.type,
    required this.targetText,
    this.options = const [],
    this.correctAnswer = '',
    this.orderIndex = 0,
  });

  factory ExamQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamQuestion(
      id: doc.id,
      examPaperId: data['examPaperId'] ?? '',
      type: data['type'] == 'pronunciation'
          ? ExamQuestionType.pronunciation
          : ExamQuestionType.mcq,
      targetText: data['targetText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
      orderIndex: data['orderIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'examPaperId': examPaperId,
        'type':
            type == ExamQuestionType.pronunciation ? 'pronunciation' : 'mcq',
        'targetText': targetText,
        'options': options,
        'correctAnswer': correctAnswer,
        'orderIndex': orderIndex,
      };
}
