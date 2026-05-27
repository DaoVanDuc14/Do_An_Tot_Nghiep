import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/sentence.dart';
import '../../../data/models/word_definition.dart';
import '../../../services/firestore_service.dart';
import '../../../services/dictionary_service.dart';
import '../../shared/widgets/pronunciation_recorder_widget.dart';
import '../../../services/pronunciation_service.dart';

class PracticeScreen extends StatefulWidget {
  final Sentence sentence;
  const PracticeScreen({super.key, required this.sentence});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSample(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final url = '${AppStrings.ttsEndpoint}?text=${Uri.encodeComponent(text)}';
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi TTS: $e')));
      }
    }
  }

  void _showDefinition(String text) async {
    if (text.trim().isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<WordDefinition>(
            future: _dictionaryService.getDefinition(text),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Đang tra từ...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text('Không thể tải định nghĩa', style: TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data!;

              // ── Nếu data là structured ──
              if (data.isStructured) {
                return _buildStructuredDefinition(data, scrollController);
              }

              // ── Fallback: raw text (backward compat) ──
              return _buildRawDefinition(data, scrollController);
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STRUCTURED DEFINITION UI
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStructuredDefinition(WordDefinition data, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── Drag handle ──
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.textLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Header: Word + Speaker + Word Type ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.word,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                      onPressed: () => _playSample(data.word),
                      tooltip: 'Nghe phát âm',
                    ),
                  ),
                ],
              ),
              if (data.wordType.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    data.wordType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),

        const SizedBox(height: 16),

        // ── Section: Nghĩa ──
        if (data.meaning.isNotEmpty)
          _buildSectionCard(
            icon: Icons.translate_rounded,
            iconColor: AppColors.primary,
            label: 'Nghĩa',
            child: Text(
              data.meaning,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                height: 1.5,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 100.ms),

        if (data.meaning.isNotEmpty) const SizedBox(height: 12),

        // ── Section: Giải thích ──
        if (data.explanation.isNotEmpty)
          _buildSectionCard(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: AppColors.warning,
            label: 'Giải thích',
            child: Text(
              data.explanation,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 200.ms),

        if (data.explanation.isNotEmpty) const SizedBox(height: 12),

        // ── Section: Ví dụ ──
        if (data.example.isNotEmpty)
          _buildSectionCard(
            icon: Icons.format_quote_rounded,
            iconColor: AppColors.accent,
            label: 'Ví dụ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vietnamese example
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 3),
                    ),
                  ),
                  child: Text(
                    data.example,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (data.exampleTranslation.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  // English translation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 18, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data.exampleTranslation,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 300.ms),

        if (data.example.isNotEmpty) const SizedBox(height: 12),

        // ── Section: Từ đồng nghĩa ──
        if (data.synonyms.isNotEmpty)
          _buildSectionCard(
            icon: Icons.link_rounded,
            iconColor: AppColors.success,
            label: 'Từ đồng nghĩa',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.synonyms.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag_rounded, size: 14, color: AppColors.success.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      s,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 400.ms),
      ],
    );
  }

  // ── Section Card builder ──
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Fallback: Raw text display (backward compat) ──
  Widget _buildRawDefinition(WordDefinition data, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.textLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                data.word.toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 28),
                onPressed: () => _playSample(data.word),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        const Text('Định nghĩa:', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          data.definition,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Gradient Header ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Luyện Phát Âm',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Câu cần đọc
                _card(
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Câu cần đọc',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      widget.sentence.text.toLowerCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.5),
                      contextMenuBuilder: (context, editableTextState) {
                        final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
                        buttonItems.insert(
                          0,
                          ContextMenuButtonItem(
                            label: 'Nghe đoạn này',
                            onPressed: () {
                              final String selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
                              _playSample(selectedText);
                              editableTextState.hideToolbar();
                            },
                          ),
                        );
                        buttonItems.insert(
                          1,
                          ContextMenuButtonItem(
                            label: 'Tra từ điển',
                            onPressed: () {
                              final String selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
                              _showDefinition(selectedText);
                              editableTextState.hideToolbar();
                            },
                          ),
                        );
                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: buttonItems,
                        );
                      },
                    ),
                  ]),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.03, end: 0, duration: 500.ms),
                const SizedBox(height: 16),

                // Kết quả & thu âm
                _card(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Kết quả nhận diện',
                        style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 20),
                  PronunciationRecorderWidget(
                    targetText: widget.sentence.text,
                    recordId: 'practice_${widget.sentence.id}',
                    showListenSample: true,
                    onResult: (result) => _saveProgress(result, widget.sentence),
                  ),
                ])).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.03, end: 0, duration: 500.ms, delay: 200.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProgress(PronunciationResult result, Sentence s) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirestoreService.saveProgress(
        uid: user.uid,
        sentenceId: s.id,
        topicId: s.topicId,
        score: result.accuracy,
      );
    }
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: child,
  );
}
