import 'package:cloud_firestore/cloud_firestore.dart';

class Sentence {
  final String id;
  final String topicId;
  final String text;
  final String audioUrl;

  Sentence({
    required this.id,
    required this.topicId,
    required this.text,
    required this.audioUrl,
  });

  factory Sentence.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Sentence(
      id: doc.id,
      topicId: data['topicId'] ?? '',
      text: data['text'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
    );
  }
}