import 'package:cloud_firestore/cloud_firestore.dart';

/// Loại bài kiểm tra online.
enum TestType { pronunciation, listeningMcq }

/// Model cho collection [online_tests] trên Firestore.
class OnlineTest {
  final String id;
  final String title;
  final TestType type;
  final String audioUrl;
  final String targetText;
  final List<String> options; // Chỉ dùng cho listeningMcq
  final int timeLimit; // Giới hạn thời gian (giây) - match Firebase field
  final DateTime? createdAt;

  OnlineTest({
    required this.id,
    required this.title,
    required this.type,
    required this.audioUrl,
    required this.targetText,
    required this.options,
    this.timeLimit = 0,
    this.createdAt,
  });

  factory OnlineTest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OnlineTest(
      id: doc.id,
      title: data['title'] ?? '',
      type:
          data['type'] == 'pronunciation'
              ? TestType.pronunciation
              : TestType.listeningMcq,
      audioUrl: data['audioUrl'] ?? '',
      targetText: data['targetText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      timeLimit: data['timeLimit'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'type': type == TestType.pronunciation ? 'pronunciation' : 'listening_mcq',
    'audioUrl': audioUrl,
    'targetText': targetText,
    'options': options,
    'timeLimit': timeLimit,
    'createdAt': Timestamp.now(),
  };
}
