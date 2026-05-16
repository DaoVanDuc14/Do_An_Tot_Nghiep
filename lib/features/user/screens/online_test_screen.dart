import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/online_test.dart';
import '../../../services/firestore_service.dart';

class OnlineTestScreen extends StatefulWidget {
  final OnlineTest test;
  const OnlineTestScreen({super.key, required this.test});

  @override
  State<OnlineTestScreen> createState() => _OnlineTestScreenState();
}

class _OnlineTestScreenState extends State<OnlineTestScreen> with TickerProviderStateMixin {
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
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(_pulseController);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isPlaying || widget.test.audioUrl.isEmpty) return;
    setState(() => _isPlaying = true);
    try {
      await _audioPlayer.play(UrlSource(widget.test.audioUrl));
      _audioPlayer.onPlayerComplete.listen((_) { if (mounted) setState(() => _isPlaying = false); });
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi phát âm: $e'))); setState(() => _isPlaying = false); }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) await _evaluate(path);
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000), path: '${dir.path}/test_record.wav');
        setState(() { _isRecording = true; _answered = false; _isCorrect = null; _accuracy = null; _recognizedText = null; });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần quyền micro để ghi âm!')));
      }
    }
  }

  Future<void> _evaluate(String filePath) async {
    setState(() => _isLoading = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse(AppStrings.evalEndpoint));
      req.fields['target_text'] = widget.test.targetText;
      req.files.add(await http.MultipartFile.fromPath('audio_file', filePath));
      final res = await req.send();
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        final data = jsonDecode(body)['data'];
        final tw = data['target_text'].toString().toLowerCase().split(' ');
        final rw = data['recognized_text'].toString().toLowerCase().split(' ');
        int c = 0;
        for (int i = 0; i < rw.length; i++) { if (i < tw.length && rw[i] == tw[i]) c++; }
        int acc = tw.isEmpty ? 0 : ((c / tw.length) * 100).round().clamp(0, 100);
        setState(() { _accuracy = acc; _isCorrect = acc >= 80; _answered = true; _recognizedText = rw.join(' '); });
        if (acc >= 80) await _addScore();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi server: ${res.statusCode}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không kết nối được AI: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectOption(String option) async {
    if (_answered) return;
    final ok = option.toLowerCase().trim() == widget.test.targetText.toLowerCase().trim();
    setState(() { _selectedOption = option; _isCorrect = ok; _answered = true; });
    if (ok) await _addScore();
  }

  Future<void> _addScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirestoreService.addScore(user.uid, 10);
  }

  @override
  Widget build(BuildContext context) {
    final isPron = widget.test.type == TestType.pronunciation;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isPron ? 'Kiểm Tra Phát Âm' : 'Nghe & Chọn Đáp Án'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Badge
          Center(child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(30)),
            child: Text(isPron ? AppStrings.pronunciationType : AppStrings.mcqType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          )),

          // Title card
          _card(child: Column(children: [
            Text(widget.test.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            if (isPron) ...[const SizedBox(height: 10), Text(widget.test.targetText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary))],
          ])),
          const SizedBox(height: 14),

          // Play button
          _card(child: Column(children: [
            const Text('Nhấn để nghe câu hỏi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _playAudio,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _isPlaying ? AppColors.accentGradient : AppColors.primaryGradient),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Icon(_isPlaying ? Icons.volume_up_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
              ),
            ),
          ])),
          const SizedBox(height: 14),

          // Pronunciation recording
          if (isPron) _card(child: Column(children: [
            const Text('Ghi âm giọng đọc của bạn', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isLoading ? null : _toggleRecording,
              child: ScaleTransition(
                scale: _isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: _isRecording ? Colors.red : AppColors.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_isRecording ? Colors.red : AppColors.accent).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))]),
                  child: _isLoading
                      ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 38),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_isRecording ? 'Đang ghi âm... Nhấn để dừng' : 'Nhấn để bắt đầu đọc', style: TextStyle(color: _isRecording ? Colors.red : Colors.grey, fontStyle: FontStyle.italic)),
            if (_answered && _accuracy != null) ...[const SizedBox(height: 20), _buildPronResult()],
          ])),

          // MCQ options
          if (!isPron) ...[
            const SizedBox(height: 4),
            ...widget.test.options.map((opt) => _buildMcqOption(opt)),
          ],

          // Result banner
          if (_answered) ...[const SizedBox(height: 16), _buildResultBanner()],
        ]),
      ),
    );
  }

  Widget _buildPronResult() {
    final acc = _accuracy ?? 0;
    final col = acc >= 80 ? Colors.green : (acc >= 50 ? Colors.orange : Colors.red);
    return Column(children: [
      if (_recognizedText != null) Text('Bạn đọc: "$_recognizedText"', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: col, width: 1.5)), child: Text('${AppStrings.accuracy}: $acc%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col))),
    ]);
  }

  Widget _buildMcqOption(String option) {
    Color bg = Colors.white;
    Color border = Colors.grey.shade200;
    IconData? icon;
    final isTarget = option.toLowerCase().trim() == widget.test.targetText.toLowerCase().trim();
    if (_answered && _selectedOption == option) {
      bg = _isCorrect! ? Colors.green.shade50 : Colors.red.shade50;
      border = _isCorrect! ? Colors.green : Colors.red;
      icon = _isCorrect! ? Icons.check_circle_rounded : Icons.cancel_rounded;
    } else if (_answered && isTarget) {
      bg = Colors.green.shade50; border = Colors.green; icon = Icons.check_circle_rounded;
    }
    return GestureDetector(
      onTap: () => _selectOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(children: [
          Expanded(child: Text(option, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary))),
          if (icon != null) Icon(icon, color: _isCorrect! ? Colors.green : Colors.red),
        ]),
      ),
    );
  }

  Widget _buildResultBanner() {
    final ok = _isCorrect ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: ok ? AppColors.successGradient : AppColors.errorGradient), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))]),
      child: Row(children: [
        Icon(ok ? Icons.star_rounded : Icons.replay_rounded, color: Colors.white, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? AppStrings.correctAnswer : AppStrings.wrongAnswer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          if (!ok) Text('Đáp án: ${widget.test.targetText}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
    child: child,
  );
}
