import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isPlaying = false;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _answered = false;
  String? _selectedOption;
  bool? _isCorrect;
  int? _accuracy;
  String? _recognizedText;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.12).animate(_pulseController);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      await _audioPlayer.play(UrlSource(widget.quiz.audioUrl));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi phát âm: $e')));
        setState(() => _isPlaying = false);
      }
    }
  }

  // ---- PRONUNCIATION MODE ----
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) await _evaluatePronunciation(path);
    } else {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/quiz_record.wav';
        const config =
            RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000);
        await _recorder.start(config, path: path);
        setState(() {
          _isRecording = true;
          _answered = false;
          _isCorrect = null;
          _accuracy = null;
          _recognizedText = null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cần quyền micro để ghi âm!')));
        }
      }
    }
  }

  Future<void> _evaluatePronunciation(String filePath) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://vanduc14-vku-pronunciation-api.hf.space/api/v1/evaluate'));
      request.fields['target_text'] = widget.quiz.targetText;
      request.files
          .add(await http.MultipartFile.fromPath('audio_file', filePath));

      var response = await request.send();
      var body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(body)['data'];
        final String targetText =
            data['target_text'].toString().toLowerCase();
        final String recognized =
            data['recognized_text'].toString().toLowerCase();

        final List<String> targetWords = targetText.split(' ');
        final List<String> recognizedWords = recognized.split(' ');

        int correct = 0;
        for (int i = 0; i < recognizedWords.length; i++) {
          if (i < targetWords.length &&
              recognizedWords[i] == targetWords[i]) {
            correct++;
          }
        }
        int acc =
            targetWords.isEmpty ? 0 : ((correct / targetWords.length) * 100).round();
        if (acc > 100) acc = 100;

        final bool passed = acc >= 80;

        setState(() {
          _accuracy = acc;
          _isCorrect = passed;
          _answered = true;
          _recognizedText = recognized;
        });

        if (passed) await _addScore();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi server: ${response.statusCode}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không kết nối được AI: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- MCQ MODE ----
  Future<void> _selectOption(String option) async {
    if (_answered) return;
    final bool correct =
        option.toLowerCase().trim() == widget.quiz.targetText.toLowerCase().trim();
    setState(() {
      _selectedOption = option;
      _isCorrect = correct;
      _answered = true;
    });
    if (correct) await _addScore();
  }

  // ---- SCORE ----
  Future<void> _addScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'totalScore': FieldValue.increment(10)});
    } catch (e) {
      debugPrint('Lỗi cộng điểm: $e');
    }
  }

  // ============================================================
  //   BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isPronunciation = widget.quiz.type == QuizType.pronunciation;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          isPronunciation ? 'Luyện Phát Âm Quiz' : 'Nghe & Chọn Đáp Án',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- TYPE BADGE ---
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF00B4D8)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isPronunciation ? '🎙 Phát Âm' : '🎧 Nghe - Chọn',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),

            // --- TITLE CARD ---
            _card(
              child: Column(
                children: [
                  Text(
                    widget.quiz.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50)),
                  ),
                  if (isPronunciation) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.quiz.targetText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF7F8C8D)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- PLAY BUTTON ---
            _card(
              child: Column(
                children: [
                  const Text('Nhấn để nghe câu hỏi',
                      style: TextStyle(
                          color: Color(0xFF7F8C8D), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _playAudio,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isPlaying
                              ? [
                                  const Color(0xFF00B4D8),
                                  const Color(0xFF0077B6)
                                ]
                              : [
                                  const Color(0xFF2C3E50),
                                  const Color(0xFF3D566E)
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2C3E50).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.volume_up_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- PRONUNCIATION MODE ---
            if (isPronunciation) ...[
              _card(
                child: Column(
                  children: [
                    const Text('Ghi âm giọng đọc của bạn',
                        style: TextStyle(
                            color: Color(0xFF7F8C8D),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleRecording,
                      child: ScaleTransition(
                        scale: _isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? Colors.red
                                : const Color(0xFF00B4D8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? Colors.red
                                        : const Color(0xFF00B4D8))
                                    .withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3))
                              : Icon(
                                  _isRecording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? 'Đang ghi âm... Nhấn để dừng'
                          : 'Nhấn để bắt đầu đọc',
                      style: TextStyle(
                          color: _isRecording ? Colors.red : Colors.grey,
                          fontStyle: FontStyle.italic),
                    ),
                    if (_answered && _accuracy != null) ...[
                      const SizedBox(height: 20),
                      _buildPronunciationResult(),
                    ]
                  ],
                ),
              ),
            ],

            // --- MCQ MODE ---
            if (!isPronunciation) ...[
              const SizedBox(height: 4),
              ...widget.quiz.options.map((opt) => _buildMcqOption(opt)),
            ],

            // --- RESULT BANNER ---
            if (_answered) ...[
              const SizedBox(height: 16),
              _buildResultBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPronunciationResult() {
    final acc = _accuracy ?? 0;
    final color =
        acc >= 80 ? Colors.green : (acc >= 50 ? Colors.orange : Colors.red);
    return Column(
      children: [
        if (_recognizedText != null)
          Text('Bạn đọc: "$_recognizedText"',
              style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
              textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            'Độ chính xác: $acc%',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildMcqOption(String option) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    IconData? trailingIcon;

    if (_answered && _selectedOption == option) {
      bgColor = _isCorrect! ? Colors.green.shade50 : Colors.red.shade50;
      borderColor = _isCorrect! ? Colors.green : Colors.red;
      trailingIcon =
          _isCorrect! ? Icons.check_circle_rounded : Icons.cancel_rounded;
    } else if (_answered &&
        option.toLowerCase().trim() ==
            widget.quiz.targetText.toLowerCase().trim()) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green;
      trailingIcon = Icons.check_circle_rounded;
    }

    return GestureDetector(
      onTap: () => _selectOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(option,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50))),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon,
                  color: _isCorrect! ? Colors.green : Colors.red)
          ],
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final correct = _isCorrect ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: correct
              ? [const Color(0xFF11998e), const Color(0xFF38ef7d)]
              : [const Color(0xFFcb2d3e), const Color(0xFFef473a)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (correct ? Colors.green : Colors.red).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.star_rounded : Icons.replay_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? '🎉 Chính xác! +10 điểm' : '❌ Chưa đúng, thử lại nào!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                if (!correct)
                  Text(
                    'Đáp án: ${widget.quiz.targetText}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }
}

