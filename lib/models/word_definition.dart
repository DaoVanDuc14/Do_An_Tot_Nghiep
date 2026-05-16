class WordDefinition {
  final String word;
  final String definition;
  final String phonetic;

  WordDefinition({
    required this.word,
    required this.definition,
    this.phonetic = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'definition': definition,
      'phonetic': phonetic,
      'updatedAt': DateTime.now(),
    };
  }

  factory WordDefinition.fromMap(String word, Map<String, dynamic> map) {
    return WordDefinition(
      word: word,
      definition: map['definition'] ?? '',
      phonetic: map['phonetic'] ?? '',
    );
  }
}
