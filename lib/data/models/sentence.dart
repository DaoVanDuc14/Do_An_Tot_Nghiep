import 'package:cloud_firestore/cloud_firestore.dart';

class Sentence {
  final String id;
  final String topicId;
  final String vietnamese;
  final String english;
  final String audioUrl;

  Sentence({
    required this.id,
    required this.topicId,
    required this.vietnamese,
    required this.english,
    required this.audioUrl,
  });

  // Alias để không vỡ code cũ đang gọi sentence.text
  String get text => vietnamese;

  factory Sentence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sentence(
      id: doc.id,
      topicId: data['topicId'] ?? '',
      // Fallback: Nếu không có vietnamese thì lấy text, nếu không có nữa thì rỗng
      vietnamese: data['vietnamese'] ?? data['text'] ?? '',
      english: data['english'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'topicId': topicId,
    'vietnamese': vietnamese,
    'english': english,
    'audioUrl': audioUrl,
  };
}
