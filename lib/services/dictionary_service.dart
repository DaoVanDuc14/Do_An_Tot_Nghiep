import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/word_definition.dart';

class DictionaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // HÀM LẤY ĐỊNH NGHĨA
  Future<WordDefinition> getDefinition(String text) async {
    final cleanText = text.trim().toLowerCase();
    
    // 1. Kiểm tra trong Firestore (Cache)
    try {
      final doc = await _firestore.collection('dictionary').doc(cleanText).get();
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
    final wordDef = WordDefinition(word: cleanText, definition: definition);
    
    final isError = definition.startsWith("Lỗi") || 
                    definition.startsWith("Không thể") || 
                    definition.startsWith("AI không tìm thấy");

    if (!isError) {
      try {
        await _firestore.collection('dictionary').doc(cleanText).set(wordDef.toMap());
        print('💾 Đã lưu định nghĩa vào Cache');
      } catch (e) {
        print('❌ Không thể lưu vào Firestore: $e');
      }
    } else {
      print('⚠️ Không lưu vào Cache do kết quả bị lỗi.');
    }

    return wordDef;
  }

  // HÀM GỌI LLM GEMINI (Sử dụng HTTP v1 Stable để đảm bảo không bị lỗi 404)
  // HÀM GỌI LLM GEMINI (Có cơ chế Retry và Fallback tự động)
  Future<String> _fetchFromLLM(String text) async {
    const apiKey = "AIzaSyCd81GTDU6eUSC7wKVUyw88JhYYcrJLXV8";
    
    // Danh sách các model theo thứ tự ưu tiên
    // Nếu bản 2.5 flash bị quá tải (503) và 2.0 bị hết Quota (429)
    // Bản 2.5-flash-lite đã được kiểm tra là hoạt động tốt nhất hiện tại.
    final modelsToTry = [
      "gemini-2.5-flash-lite", 
      "gemini-2.5-flash",
    ];

    for (String model in modelsToTry) {
      // Thử tối đa 2 lần cho mỗi model nếu gặp lỗi quá tải
      for (int attempt = 1; attempt <= 2; attempt++) {
        final url = Uri.parse("https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey");

        try {
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": "Bạn là một từ điển Việt-Anh học thuật. Hãy định nghĩa từ/cụm từ '$text' bằng tiếng Anh. Yêu cầu: Ngắn gọn dưới 20 từ, đầu tiên nêu rõ từ loại (danh từ, động từ, tính từ), không bao gồm lời dẫn, không lặp lại từ gốc. Kết quả trả về gồm loại từ sau đó là nội dung định nghĩa."}
                  ]
                }
              ]
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['candidates'] != null && data['candidates'].isNotEmpty) {
              print('✅ Lấy định nghĩa từ Gemini ($model) thành công!');
              return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
            }
            return "AI không tìm thấy kết quả.";
          } 
          // 503 (Unavailable/Overloaded) hoặc 429 (Too Many Requests)
          else if (response.statusCode == 503 || response.statusCode == 429) {
            print('⚠️ Server quá tải với model $model (Mã: ${response.statusCode}, Lần thử: $attempt/2)');
            if (attempt < 2) {
              await Future.delayed(const Duration(seconds: 2)); // Chờ 2 giây rồi thử lại
              continue;
            }
          } 
          // Lỗi khác (ví dụ 400 Bad Request, 403 Forbidden, 404 Not Found)
          else {
            print('⚠️ Lỗi API với $model (${response.statusCode}): ${response.body}');
            break; // Dừng vòng lặp attempt, lập tức chuyển sang model tiếp theo (fallback)
          }
        } catch (e) {
          print('❌ Lỗi kết nối mạng khi gọi $model: $e');
          break; // Mất mạng, chuyển sang model tiếp theo
        }
      }
    }

    return "Lỗi: Hệ thống AI đang quá tải, vui lòng thử lại sau.";
  }
}
