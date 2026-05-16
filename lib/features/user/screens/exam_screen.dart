import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/online_test.dart';
import 'exam_result_screen.dart';

class ExamScreen extends StatefulWidget {
  final List<OnlineTest> questions;
  final String examTitle;
  const ExamScreen({super.key, required this.questions, this.examTitle = 'Bài Kiểm Tra'});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _answers = {};
  int _idx = 0;
  bool _started = false;
  bool _isPlaying = false;
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    // Dùng timeLimit từ Firebase nếu có, ngược lại tính tự động
    final fromFirebase = widget.questions
        .where((q) => q.timeLimit > 0)
        .fold(0, (sum, q) => sum + q.timeLimit);
    _remaining = fromFirebase > 0
        ? fromFirebase
        : widget.questions.length * 60;
  }

  @override
  void dispose() { _timer?.cancel(); _player.dispose(); super.dispose(); }

  void _startExam() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        _autoSubmit();
      } else if (mounted) {
        setState(() => _remaining--);
      }
    });
  }

  void _autoSubmit() {
    if (!mounted) return;
    _timer?.cancel();
    _goToResult(autoSubmit: true);
  }

  void _goToResult({bool autoSubmit = false}) {
    _timer?.cancel();
    int correct = 0;
    for (final q in widget.questions) {
      if (q.type == TestType.listeningMcq) {
        final ans = _answers[q.id];
        if (ans != null && ans.trim().toLowerCase() == q.targetText.trim().toLowerCase()) correct++;
      }
    }
    final timeSpent = widget.questions.length * 60 - _remaining;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ExamResultScreen(
      questions: widget.questions,
      answers: _answers,
      correctCount: correct,
      timeSpentSeconds: timeSpent,
      examTitle: widget.examTitle,
    )));
  }

  Future<void> _playAudio(String url) async {
    if (_isPlaying) { await _player.stop(); setState(() => _isPlaying = false); return; }
    setState(() => _isPlaying = true);
    await _player.play(UrlSource(url));
    _player.onPlayerComplete.listen((_) { if (mounted) setState(() => _isPlaying = false); });
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _showGrid() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Danh sách câu hỏi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primary)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
            itemCount: widget.questions.length,
            itemBuilder: (_, i) {
              final q = widget.questions[i];
              final isAnswered = _answers.containsKey(q.id);
              final isCurrent = i == _idx;
              return GestureDetector(
                onTap: () { setState(() => _idx = i); Navigator.pop(context); },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary : (isAnswered ? AppColors.accent : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(10),
                    border: isCurrent ? null : Border.all(color: Colors.transparent),
                  ),
                  child: Center(child: Text('${i + 1}', style: TextStyle(color: isCurrent || isAnswered ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold))),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendDot(AppColors.primary, 'Đang làm'),
            const SizedBox(width: 16),
            _legendDot(AppColors.accent, 'Đã làm'),
            const SizedBox(width: 16),
            _legendDot(Colors.grey.shade200, 'Chưa làm'),
          ]),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]);

  void _confirmSubmit() {
    final answered = _answers.length;
    final total = widget.questions.length;
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nộp bài?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      content: Text('Bạn đã trả lời $answered/$total câu.\n${total - answered > 0 ? '⚠️ Còn ${total - answered} câu chưa làm.' : '✅ Đã hoàn thành tất cả!'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tiếp tục làm', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(context); _goToResult(); },
          child: const Text('Nộp bài', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ─── PRE-EXAM SCREEN ──────────────────────────────────────
  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), shape: BoxShape.circle),
              child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 24),
            Text(widget.examTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 24),
            _infoRow(Icons.help_outline, '${widget.questions.length} câu hỏi'),
            const SizedBox(height: 12),
            _infoRow(Icons.timer_outlined, 'Thời gian: ${_formatTime(_remaining)}'),
            const SizedBox(height: 12),
            _infoRow(Icons.star_outline, 'Mỗi câu đúng: 10 điểm'),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _startExam,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              label: const Text('Bắt đầu làm bài', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, color: AppColors.primary, size: 22),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
  ]);

  // ─── EXAM SCREEN ──────────────────────────────────────────
  Widget _buildExamScreen() {
    final q = widget.questions[_idx];
    final isMcq = q.type == TestType.listeningMcq;
    final answered = _answers.length;
    final total = widget.questions.length;
    final timerColor = _remaining < 60 ? Colors.red : (_remaining < 300 ? Colors.orange : AppColors.accent);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Icon(Icons.timer_outlined, color: timerColor, size: 20),
          const SizedBox(width: 6),
          Text(_formatTime(_remaining), style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          Text('Câu ${_idx + 1}/$total', style: const TextStyle(fontSize: 15)),
          const Spacer(),
          TextButton(
            onPressed: _confirmSubmit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text('Nộp bài', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: answered / total, backgroundColor: Colors.white24, color: AppColors.accent, minHeight: 6),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Question card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: (isMcq ? AppColors.accent : AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(isMcq ? '🎧 Nghe - Chọn đáp án' : '🎙 Phát âm', style: TextStyle(color: isMcq ? AppColors.accent : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              Text('Câu ${_idx + 1}. ${q.title}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (q.audioUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _playAudio(q.audioUrl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64, height: 64,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: _isPlaying ? AppColors.accentGradient : AppColors.primaryGradient), shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
                    child: Icon(_isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_isPlaying ? 'Đang phát...' : 'Nhấn để nghe', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // MCQ Options
          if (isMcq) ...q.options.map((opt) {
            final isSelected = _answers[q.id] == opt;
            return GestureDetector(
              onTap: () => setState(() => _answers[q.id] = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: isSelected ? 2 : 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? AppColors.primary : Colors.grey.shade100),
                    child: Icon(isSelected ? Icons.check_rounded : null, color: Colors.white, size: 18)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(opt, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.textPrimary))),
                ]),
              ),
            );
          }),

          // Pronunciation note
          if (!isMcq) Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: const Text('📝 Câu phát âm - hãy luyện tập riêng ở mục Luyện tập', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _idx > 0 ? () => setState(() => _idx--) : null,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.primary)),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            label: const Text('Trước'),
          )),
          const SizedBox(width: 12),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.grid_view_rounded, color: AppColors.primary), onPressed: _showGrid, tooltip: 'Danh sách câu'),
          ),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: _idx < widget.questions.length - 1 ? () => setState(() => _idx++) : _confirmSubmit,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: Icon(_idx < widget.questions.length - 1 ? Icons.arrow_forward_ios_rounded : Icons.check_rounded, size: 16),
            label: Text(_idx < widget.questions.length - 1 ? 'Tiếp theo' : 'Nộp bài', style: const TextStyle(color: Colors.white)),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _started ? _buildExamScreen() : _buildStartScreen();
}
