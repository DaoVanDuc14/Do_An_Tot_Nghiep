import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho collection [exam_papers] trên Firestore.
class ExamPaper {
  final String id;
  final String title;
  final int durationMinutes;
  final DateTime? createdAt;
  final String creatorId;
  final String creatorName;
  final bool isPublished;

  ExamPaper({
    required this.id,
    required this.title,
    required this.durationMinutes,
    this.createdAt,
    this.creatorId = '',
    this.creatorName = '',
    this.isPublished = false,
  });

  factory ExamPaper.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamPaper(
      id: doc.id,
      title: data['title'] ?? '',
      durationMinutes: data['duration_minutes'] as int? ?? 30,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      isPublished: data['isPublished'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'duration_minutes': durationMinutes,
    'createdAt': Timestamp.now(),
    'creatorId': creatorId,
    'creatorName': creatorName,
    'isPublished': isPublished,
  };
}
