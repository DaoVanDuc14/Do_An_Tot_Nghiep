import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../data/models/word_definition.dart';

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
    final wordDef = WordDefinition.fromLLMResponse(cleanText, definition);
    
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
    const apiKey = "AIzaSyBIPetIHry3u12sBJ0gq_6m3zl8ihHLu2k";
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
                    {"text": """
                        Bạn là một từ điển AI chuyên hỗ trợ người nước ngoài học tiếng Việt.

                        Nhiệm vụ:
                        Giải thích từ hoặc cụm từ tiếng Việt: '$text'

                        Yêu cầu:
                        - Giải thích bằng tiếng Anh đơn giản, dễ hiểu cho người mới học tiếng Việt.
                        - Nếu là cụm từ hoặc thành ngữ, hãy giải thích theo nghĩa thực tế.
                        - Không giải thích quá học thuật.
                        - Không dài dòng.
                        - Không lặp lại từ gốc trong định nghĩa.
                        - Ưu tiên cách dùng thực tế trong giao tiếp hằng ngày.
                        

                        BẮT BUỘC trả về đúng format sau:

                        Loại từ: ...
                        Nghĩa: ...
                        Giải thích: ...
                        Ví dụ: ...
                        Dịch ví dụ: ...
                        Từ đồng nghĩa: ...

                        Quy tắc:
                        - "Loại từ" viết bằng tiếng Anh (noun, verb, adjective, adverb, phrase...)
                        - "Nghĩa" tối đa 1 dòng ngắn gọn
                        - "Giải thích" dưới 25 từ
                        - "Ví dụ" là câu tiếng Việt tự nhiên
                        - "Dịch ví dụ" là tiếng Anh
                        - "Từ đồng nghĩa" ghi 1-3 từ đơn giản nếu có
                        - Nếu không có từ đồng nghĩa thì ghi: None
                        - Không thêm markdown (bắt buộc)
                        - Không thêm ký tự đặc biệt (bắt buộc)
                        - Không thêm lời mở đầu (bắt buộc)
                        - Trả kết quả dưới dạng JSON hợp lệ. (bắt buộc)

                        Ví dụ kết quả:

                        Loại từ: verb
                        Nghĩa: to communicate or share information
                        Giải thích: Exchange ideas, feelings, or information with others.
                        Ví dụ: Tôi thường giao tiếp với khách hàng bằng tiếng Anh.
                        Dịch ví dụ: I usually communicate with customers in English.
                        Từ đồng nghĩa: nói chuyện, liên lạc
                        """
                    }
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
