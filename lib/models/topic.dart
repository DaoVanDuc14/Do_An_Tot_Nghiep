import 'package:cloud_firestore/cloud_firestore.dart';

class Topic {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  // --- 3 TRƯỜNG DỮ LIỆU MỚI ---
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
    Map data = doc.data() as Map<String, dynamic>;
    return Topic(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      // Lấy dữ liệu mới, nếu chủ đề cũ không có thì gán mặc định
      uid: data['uid'] ?? '',
      authorName: data['authorName'] ?? 'Ẩn danh',
      isPublic: data['isPublic'] ?? false,
    );
  }
}