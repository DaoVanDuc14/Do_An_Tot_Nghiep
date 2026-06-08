import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../data/models/word_definition.dart';

class DictionaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // HÀM LẤY ĐỊNH NGHĨA
  Future<WordDefinition> getDefinition(String text) async {
    final cleanText = text.trim().toLowerCase();

    // 1. Kiểm tra trong Firestore (Cache)
    try {
      final doc =
          await _firestore.collection('dictionary').doc(cleanText).get();
      if (doc.exists) {
        print('✅ Lấy định nghĩa từ Cache (Firestore)');
        return WordDefinition.fromMap(cleanText, doc.data()!);
      }
    } catch (e) {
      print('❌ Lỗi Firestore: $e');
    }

    // 2. Nếu không có, gọi LLM
    print('📡 Đang gọi LLM (Gemini) để lấy định nghĩa...');
    final definition = await _fetchFromLLM(cleanText);

    // 3. Chỉ lưu vào Firestore nếu không phải thông báo lỗi
    final wordDef = WordDefinition.fromLLMResponse(cleanText, definition);

    final isError =
        definition.startsWith("Lỗi") ||
        definition.startsWith("Không thể") ||
        definition.startsWith("AI không tìm thấy");

    if (!isError) {
      try {
        await _firestore
            .collection('dictionary')
            .doc(cleanText)
            .set(wordDef.toMap());
        print('💾 Đã lưu định nghĩa vào Cache');
      } catch (e) {
        print('❌ Không thể lưu vào Firestore: $e');
      }
    } else {
      print('⚠️ Không lưu vào Cache do kết quả bị lỗi.');
    }

    return wordDef;
  }

  // HÀM GỌI API TRÊN VPS
  Future<String> _fetchFromLLM(String text) async {
    try {
      // Gọi API nội bộ của chúng ta thay vì gọi trực tiếp lên Gemini
      final url = Uri.parse(AppStrings.dictionaryEndpoint);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['definition'].toString().trim();
      } else {
        print('⚠️ Lỗi API từ VPS (${response.statusCode}): ${response.body}');
        return "Lỗi: Hệ thống AI đang quá tải, vui lòng thử lại sau.";
      }
    } catch (e) {
      print('❌ Lỗi kết nối mạng: $e');
      return "Lỗi: Không thể kết nối tới máy chủ AI.";
    }
  }
}
