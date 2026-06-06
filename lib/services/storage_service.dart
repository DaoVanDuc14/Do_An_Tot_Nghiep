import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';

/// Service upload Firebase Storage hỗ trợ cả Web (bytes) và Mobile (File).
///
/// Hiện tại chỉ dùng cho upload ảnh đại diện (avatar).
/// Audio được phát qua TTS API, không cần lưu vào Storage.
class StorageService {
  StorageService._();

  static final _storage = FirebaseStorage.instance;

  // ─── IMAGE UPLOAD ──────────────────────────────────────────

  static Future<String> uploadImageFromPath(
    String filePath, {
    String folder = 'avatars',
  }) async {
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${filePath.split(Platform.pathSeparator).last}';
    final ref = _storage.ref().child('$folder/$name');
    final snapshot = await ref.putFile(File(filePath)).whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  static Future<String> uploadImageFromBytes(
    Uint8List bytes,
    String fileName, {
    String folder = 'avatars',
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child('$folder/$name');
    final snapshot = await ref
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
        .whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload ảnh chung: tự động chọn bytes (web) hoặc path (mobile).
  static Future<String> uploadImage({
    String? filePath,
    Uint8List? bytes,
    String? fileName,
    String folder = 'avatars',
  }) async {
    if (kIsWeb && bytes != null) {
      return uploadImageFromBytes(
        bytes,
        fileName ?? 'avatar.jpg',
        folder: folder,
      );
    } else if (!kIsWeb && filePath != null) {
      return uploadImageFromPath(filePath, folder: folder);
    }
    throw Exception('StorageService: Không có dữ liệu file để upload!');
  }
}
