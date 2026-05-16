import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_paper.dart';
import '../../../data/models/exam_question.dart';
import '../../../services/firestore_service.dart';
import 'leaderboard_screen.dart';

class NewExamResultScreen extends StatefulWidget {
  final ExamPaper paper;
  final List<ExamQuestion> questions;
  final Map<String, Map<String, dynamic>> answers;
  final int correctCount;
  final int timeSpentSeconds;
  final bool isAutoSubmit;

  const NewExamResultScreen({
    super.key,
    required this.paper,
    required this.questions,
    required this.answers,
    required this.correctCount,
    required this.timeSpentSeconds,
    this.isAutoSubmit = false,
  });

  @override
  State<NewExamResultScreen> createState() => _NewExamResultScreenState();
}

class _NewExamResultScreenState extends State<NewExamResultScreen> {
  bool _saved = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _saveFailed = true); return; }
    final score = widget.correctCount * 10;
    try {
      final userData = await FirestoreService.getUserData(user.uid);
      final userName = userData?['name'] as String? ?? 'Ẩn danh';

      // Chuẩn bị answers map cho Firestore
      final answersForDb = <String, dynamic>{};
      for (final entry in widget.answers.entries) {
        answersForDb[entry.key] = entry.value;
      }
      await FirestoreService.saveExamResultDetailed(
        userId: user.uid,
        name: userName,
        examPaperId: widget.paper.id,
        score: score,
        totalQuestions: widget.questions.length,
        answers: answersForDb,
        durationSeconds: widget.timeSpentSeconds,
        isAutoSubmit: widget.isAutoSubmit,
      );
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      debugPrint('Lỗi lưu kết quả: $e');
      if (mounted) {
        setState(() => _saveFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ Lỗi lưu: $e'), backgroundColor: Colors.orange));
      }
    }
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final score = widget.correctCount * 10;
    final pct = total == 0 ? 0.0 : widget.correctCount / total;
    final color = pct >= 0.8 ? AppColors.success : (pct >= 0.5 ? AppColors.warning : AppColors.error);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kết Quả Bài Thi'),
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.paper.title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
          if (widget.isAutoSubmit) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text('⏰ Bài thi đã tự động nộp vì hết thời gian', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 20),

          // Score circle
          Center(child: Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.8), color]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$score', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('điểm', style: TextStyle(fontSize: 15, color: Colors.white70)),
            ]),
          )),
          const SizedBox(height: 20),
          Text(pct >= 0.8 ? '🎉 Xuất sắc!' : (pct >= 0.5 ? '👍 Khá tốt!' : '💪 Cố gắng hơn!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 20),

          // Stats
          Row(children: [
            Expanded(child: _stat('✅ Đúng', '${widget.correctCount}/$total', AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _stat('❌ Sai', '${total - widget.correctCount}/$total', AppColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _stat('⏱ Thời gian', _fmt(widget.timeSpentSeconds), AppColors.accent)),
          ]),
          const SizedBox(height: 24),

          // Detail
          const Text('Chi tiết câu trả lời', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          ...widget.questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final ans = widget.answers[q.id];
            final isMcq = q.type == ExamQuestionType.mcq;
            final isPron = q.type == ExamQuestionType.pronunciation;
            final isCorrect = ans != null && ans['isCorrect'] == true;
            final isAnswered = ans != null;

            Color borderColor;
            IconData icon;
            Color iconColor;
            if (!isAnswered) {
              borderColor = Colors.grey.shade200;
              icon = Icons.remove_circle_outline;
              iconColor = Colors.grey;
            } else if (isCorrect) {
              borderColor = AppColors.success;
              icon = Icons.check_circle_rounded;
              iconColor = AppColors.success;
            } else {
              borderColor = AppColors.error;
              icon = Icons.cancel_rounded;
              iconColor = AppColors.error;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Câu ${i + 1}: ${q.targetText}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),

                  if (isMcq && isAnswered) ...[
                    Text('Bạn chọn: ${ans['selected'] ?? '?'}',
                        style: TextStyle(fontSize: 12, color: isCorrect ? AppColors.success : AppColors.error)),
                    if (!isCorrect)
                      Text('Đáp án: ${q.correctAnswer}', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                  ],

                  if (isPron && isAnswered)
                    Text('🎙 Accuracy: ${ans['accuracy']}% — ${isCorrect ? '✅ ĐẠT' : '❌ CHƯA ĐẠT'}',
                        style: TextStyle(fontSize: 12, color: isCorrect ? AppColors.success : AppColors.error, fontWeight: FontWeight.w500)),

                  if (!isAnswered)
                    const Text('Chưa trả lời', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
              ]),
            );
          }),
          const SizedBox(height: 20),

          // Actions
          if (_saved)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
              label: const Text('Xem Bảng Xếp Hạng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else if (_saveFailed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Không lưu được kết quả.', style: TextStyle(color: Colors.orange, fontSize: 13))),
              ]),
            )
          else
            const Center(child: Column(children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 8),
              Text('Đang lưu kết quả...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ])),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: AppColors.primary)),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            icon: const Icon(Icons.home_rounded, color: AppColors.primary),
            label: const Text('Về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}
