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
import '../../shared/pronunciation_recorder_widget.dart';
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: FutureBuilder<WordDefinition>(
          future: _dictionaryService.getDefinition(text),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('Lỗi khi tải định nghĩa', style: TextStyle(color: Colors.red))),
              );
            }

            final data = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.word.toUpperCase(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          if (data.phonetic.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              data.phonetic,
                              style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
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
                  style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, height: 1.5),
                ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
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
