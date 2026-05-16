import 'package:cloud_firestore/cloud_firestore.dart';

enum QuizType { pronunciation, listeningMcq }

class Quiz {
  final String id;
  final String topicId;
  final String title;
  final QuizType type;
  final String audioUrl;
  final String targetText;
  final List<String> options; // Chỉ dùng cho listeningMcq

  Quiz({
    required this.id,
    required this.topicId,
    required this.title,
    required this.type,
    required this.audioUrl,
    required this.targetText,
    required this.options,
  });

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Quiz(
      id: doc.id,
      topicId: data['topicId'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] == 'pronunciation'
          ? QuizType.pronunciation
          : QuizType.listeningMcq,
      audioUrl: data['audioUrl'] ?? '',
      targetText: data['targetText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'title': title,
      'type': type == QuizType.pronunciation ? 'pronunciation' : 'listening_mcq',
      'audioUrl': audioUrl,
      'targetText': targetText,
      'options': options,
    };
  }
}
