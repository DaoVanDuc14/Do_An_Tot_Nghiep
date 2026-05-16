import 'package:cloud_firestore/cloud_firestore.dart';

class Topic {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String uid;
  final String authorName;
  final bool isPublic;

  Topic({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.uid,
    required this.authorName,
    required this.isPublic,
  });

  factory Topic.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Topic(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      uid: data['uid'] ?? '',
      authorName: data['authorName'] ?? 'Ẩn danh',
      isPublic: data['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'uid': uid,
        'authorName': authorName,
        'isPublic': isPublic,
      };
}
