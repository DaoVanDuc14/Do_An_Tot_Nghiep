import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';

/// Service upload Firebase Storage hỗ trợ cả Web (bytes) và Mobile (File).
class StorageService {
  StorageService._();

  static final _storage = FirebaseStorage.instance;

  /// Upload audio từ File path (mobile). Trả về download URL.
  static Future<String> uploadAudioFromPath(
    String filePath, {
    String folder = 'online_tests',
  }) async {
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${filePath.split(Platform.pathSeparator).last}';
    final ref = _storage.ref().child('$folder/$name');
    final snapshot = await ref.putFile(File(filePath)).whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload audio từ bytes (web). Trả về download URL.
  static Future<String> uploadAudioFromBytes(
    Uint8List bytes,
    String fileName, {
    String folder = 'online_tests',
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child('$folder/$name');
    final snapshot = await ref
        .putData(bytes, SettableMetadata(contentType: 'audio/mpeg'))
        .whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

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

  static Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  /// Upload audio chung: tự động chọn bytes (web) hoặc path (mobile).
  static Future<String> uploadAudio({
    String? filePath,
    Uint8List? bytes,
    String? fileName,
    String folder = 'online_tests',
  }) async {
    if (kIsWeb && bytes != null) {
      return uploadAudioFromBytes(
        bytes,
        fileName ?? 'audio.wav',
        folder: folder,
      );
    } else if (!kIsWeb && filePath != null) {
      return uploadAudioFromPath(filePath, folder: folder);
    }
    throw Exception('StorageService: Không có dữ liệu file để upload!');
  }

  /// Upload audio cho exam question: đường dẫn chuẩn /test_audios/{examId}/{timestamp}.ext
  ///
  /// - Web  : truyền [bytes] từ result.files.first.bytes (FilePicker withData: true)
  /// - Mobile: truyền [filePath] từ result.files.first.path
  ///
  /// Quan trọng: sử dụng `uploadTask.whenComplete()` trước `getDownloadURL()`
  /// để tránh lỗi [firebase_storage/object-not-found] trên môi trường Web,
  /// xảy ra khi Storage chưa commit xong object mà đã gọi getDownloadURL().
  static Future<String> uploadAudioForExam({
    required String examId,
    Uint8List? bytes, // Web: từ FilePicker.files.first.bytes
    String? filePath, // Mobile: từ FilePicker.files.first.path
    String? fileName,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = (fileName ?? 'audio.mp3').split('.').last;
    final storagePath = 'test_audios/$examId/$ts.$ext';
    final ref = _storage.ref().child(storagePath);

    try {
      final TaskSnapshot snapshot;

      if (kIsWeb && bytes != null) {
        // Web path: upload bytes → chờ whenComplete() trước khi lấy URL
        final UploadTask uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'audio/mpeg'),
        );
        snapshot = await uploadTask.whenComplete(() {});
      } else if (!kIsWeb && filePath != null) {
        // Mobile path: upload từ File → chờ whenComplete()
        final UploadTask uploadTask = ref.putFile(File(filePath));
        snapshot = await uploadTask.whenComplete(() {});
      } else {
        throw Exception(
          'StorageService.uploadAudioForExam: Thiếu dữ liệu file!\n'
          'Web cần bytes != null; Mobile cần filePath != null.',
        );
      }

      // Kiểm tra trạng thái upload trước khi lấy URL
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload không thành công, state=${snapshot.state}');
      }

      // Chỉ gọi getDownloadURL() sau khi đã xác nhận upload thành công
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('Firebase Storage lỗi [${e.code}]: ${e.message}');
    }
  }

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
