import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_strings.dart';

/// Kết quả chấm phát âm từ API.
class PronunciationResult {
  final String targetText;
  final String recognizedText;
  final int accuracy;
  final bool passed;

  PronunciationResult({
    required this.targetText,
    required this.recognizedText,
    required this.accuracy,
    required this.passed,
  });
}

/// Service dùng chung cho cả Practice và Exam.
/// Gọi API evaluate phát âm và tính accuracy.
class PronunciationService {
  PronunciationService._();

  static const int passThreshold = 80;

  /// Gửi file audio lên API, trả về [PronunciationResult].
  /// Throws [Exception] nếu lỗi mạng hoặc server.
  static Future<PronunciationResult> evaluate({
    required String targetText,
    required String audioFilePath,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse(AppStrings.evalEndpoint),
      );
      req.fields['target_text'] = targetText;
      req.files.add(
        await http.MultipartFile.fromPath('audio_file', audioFilePath),
      );

      final res = await req.send().timeout(const Duration(seconds: 30));
      final body = await res.stream.bytesToString();

      if (res.statusCode != 200) {
        throw Exception('Server trả về lỗi: ${res.statusCode}');
      }

      final data = jsonDecode(body)['data'];
      final tw = data['target_text'].toString().toLowerCase().split(' ');
      final rw = data['recognized_text'].toString().toLowerCase().split(' ');

      int correct = 0;
      for (int i = 0; i < rw.length; i++) {
        if (i < tw.length && rw[i] == tw[i]) correct++;
      }
      final acc =
          tw.isEmpty ? 0 : ((correct / tw.length) * 100).round().clamp(0, 100);

      return PronunciationResult(
        targetText: data['target_text'] ?? targetText,
        recognizedText: data['recognized_text'] ?? '',
        accuracy: acc,
        passed: acc >= passThreshold,
      );
    } catch (e) {
      throw Exception('Không thể chấm phát âm: $e');
    }
  }
}
