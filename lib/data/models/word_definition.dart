import 'dart:convert';

class WordDefinition {
  final String word;
  final String definition; // Raw fallback (for backward compat)
  final String wordType; // noun, verb, adjective, phrase...
  final String meaning; // Nghĩa (tiếng Anh ngắn gọn)
  final String explanation; // Giải thích
  final String example; // Ví dụ (câu tiếng Việt)
  final String exampleTranslation; // Dịch ví dụ (tiếng Anh)
  final List<String> synonyms; // Từ đồng nghĩa

  /// Kiểm tra xem data có phải dạng structured hay chỉ là raw text
  bool get isStructured =>
      wordType.isNotEmpty || meaning.isNotEmpty || explanation.isNotEmpty;

  WordDefinition({
    required this.word,
    this.definition = '',
    this.wordType = '',
    this.meaning = '',
    this.explanation = '',
    this.example = '',
    this.exampleTranslation = '',
    this.synonyms = const [],
  });

  // ── Serialize → Firestore ──
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'definition': definition,
      'wordType': wordType,
      'meaning': meaning,
      'explanation': explanation,
      'example': example,
      'exampleTranslation': exampleTranslation,
      'synonyms': synonyms,
      'updatedAt': DateTime.now(),
    };
  }

  // ── Deserialize ← Firestore (backward compatible) ──
  factory WordDefinition.fromMap(String word, Map<String, dynamic> map) {
    List<String> parseSynonyms(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        final cleaned = raw.trim();
        if (cleaned.isEmpty || cleaned.toLowerCase() == 'none') return [];
        return cleaned
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    return WordDefinition(
      word: word,
      definition: map['definition'] ?? '',
      wordType: map['wordType'] ?? '',
      meaning: map['meaning'] ?? '',
      explanation: map['explanation'] ?? '',
      example: map['example'] ?? '',
      exampleTranslation: map['exampleTranslation'] ?? '',
      synonyms: parseSynonyms(map['synonyms']),
    );
  }

  // ── Parse raw LLM response text → structured WordDefinition ──
  factory WordDefinition.fromLLMResponse(String word, String rawText) {
    // ── Helper: parse synonyms from various formats ──
    List<String> parseSynonymsValue(dynamic raw) {
      if (raw == null) return [];
      if (raw is List)
        return raw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      if (raw is String) {
        final cleaned = raw.trim();
        if (cleaned.isEmpty ||
            cleaned.toLowerCase() == 'none' ||
            cleaned.toLowerCase() == 'không có')
          return [];
        return cleaned
            .split(RegExp(r'[,،、]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.toLowerCase() != 'none')
            .toList();
      }
      return [];
    }

    // ══════════════════════════════════════════
    //  1. Thử parse JSON trước (LLM trả JSON)
    // ══════════════════════════════════════════
    try {
      // Loại bỏ markdown code fences nếu có (```json ... ```)
      String jsonStr = rawText.trim();
      final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?\s*```');
      final codeMatch = codeBlockRegex.firstMatch(jsonStr);
      if (codeMatch != null) {
        jsonStr = codeMatch.group(1)!.trim();
      }

      // Tìm JSON object trong text (bắt đầu { kết thúc })
      final jsonObjRegex = RegExp(r'\{[\s\S]*\}');
      final jsonMatch = jsonObjRegex.firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;

        // Import dart:convert được dùng ở đây
        final Map<String, dynamic> json = _parseJson(jsonStr);

        final wordType =
            (json['Loại từ'] ?? json['loai_tu'] ?? json['wordType'] ?? '')
                .toString()
                .trim();
        final meaning =
            (json['Nghĩa'] ?? json['nghia'] ?? json['meaning'] ?? '')
                .toString()
                .trim();
        final explanation =
            (json['Giải thích'] ??
                    json['giai_thich'] ??
                    json['explanation'] ??
                    '')
                .toString()
                .trim();
        final example =
            (json['Ví dụ'] ?? json['vi_du'] ?? json['example'] ?? '')
                .toString()
                .trim();
        final exampleTranslation =
            (json['Dịch ví dụ'] ??
                    json['dich_vi_du'] ??
                    json['exampleTranslation'] ??
                    '')
                .toString()
                .trim();
        final synonyms = parseSynonymsValue(
          json['Từ đồng nghĩa'] ?? json['tu_dong_nghia'] ?? json['synonyms'],
        );

        if (wordType.isNotEmpty ||
            meaning.isNotEmpty ||
            explanation.isNotEmpty) {
          return WordDefinition(
            word: word,
            definition: rawText,
            wordType: wordType,
            meaning: meaning,
            explanation: explanation,
            example: example,
            exampleTranslation: exampleTranslation,
            synonyms: synonyms,
          );
        }
      }
    } catch (_) {
      // JSON parse thất bại → tiếp tục với regex
    }

    // ══════════════════════════════════════════
    //  2. Fallback: parse dạng text "Label: value"
    // ══════════════════════════════════════════
    String extract(String text, String label) {
      final pattern = RegExp(
        r'(?:^|\n)\s*' + RegExp.escape(label) + r'\s*:\s*(.*)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
      return '';
    }

    return WordDefinition(
      word: word,
      definition: rawText,
      wordType: extract(rawText, 'Loại từ'),
      meaning: extract(rawText, 'Nghĩa'),
      explanation: extract(rawText, 'Giải thích'),
      example: extract(rawText, 'Ví dụ'),
      exampleTranslation: extract(rawText, 'Dịch ví dụ'),
      synonyms: parseSynonymsValue(extract(rawText, 'Từ đồng nghĩa')),
    );
  }

  /// Helper parse JSON string → Map
  static Map<String, dynamic> _parseJson(String jsonStr) {
    return Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
  }
}
