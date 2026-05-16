import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/online_test.dart';
import '../../../services/firestore_service.dart';
import 'leaderboard_screen.dart';

class ExamResultScreen extends StatefulWidget {
  final List<OnlineTest> questions;
  final Map<String, String> answers;
  final int correctCount;
  final int timeSpentSeconds;
  final String examTitle;

  const ExamResultScreen({
    super.key,
    required this.questions,
    required this.answers,
    required this.correctCount,
    required this.timeSpentSeconds,
    this.examTitle = 'Bài Kiểm Tra',
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final total = widget.questions.where((q) => q.type == TestType.listeningMcq).length;
    final score = widget.correctCount * 10;
    try {
      await FirestoreService.saveTestResult(
        uid: user.uid,
        name: user.displayName ?? user.email ?? 'Người dùng',
        totalScore: score,         // renamed from score
        totalQuestions: total,
        correctAnswers: widget.correctCount,
        timeFinished: widget.timeSpentSeconds, // renamed from timeSpentSeconds
        testGroupId: 'general',    // match Firebase: testGroupId
      );
      if (mounted) setState(() => _saved = true);
    } catch (e) { debugPrint('Lỗi lưu kết quả: $e'); }
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.where((q) => q.type == TestType.listeningMcq).length;
    final score = widget.correctCount * 10;
    final pct = total == 0 ? 0.0 : widget.correctCount / total;
    final color = pct >= 0.8 ? AppColors.success : (pct >= 0.5 ? AppColors.warning : AppColors.error);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kết Quả Bài Thi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Score circle
          Center(child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('điểm', style: TextStyle(fontSize: 16, color: Colors.white70)),
            ]),
          )),
          const SizedBox(height: 24),
          Text(pct >= 0.8 ? '🎉 Xuất sắc!' : (pct >= 0.5 ? '👍 Khá tốt!' : '💪 Cố gắng hơn nhé!'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 24),

          // Stats grid
          Row(children: [
            Expanded(child: _statCard('✅ Đúng', '${widget.correctCount}/$total', AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('❌ Sai', '${total - widget.correctCount}/$total', AppColors.error)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('⏱ Thời gian', _formatTime(widget.timeSpentSeconds), AppColors.accent)),
          ]),
          const SizedBox(height: 20),

          // Review wrong answers
          const Text('Chi tiết câu trả lời', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          ...widget.questions.where((q) => q.type == TestType.listeningMcq).toList().asMap().entries.map((e) {
            final i = e.key; final q = e.value;
            final ans = widget.answers[q.id];
            final isOk = ans != null && ans.trim().toLowerCase() == q.targetText.trim().toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isOk ? AppColors.success : (ans == null ? Colors.grey.shade200 : AppColors.error), width: 1.5),
              ),
              child: Row(children: [
                Icon(isOk ? Icons.check_circle_rounded : (ans == null ? Icons.remove_circle_outline : Icons.cancel_rounded),
                    color: isOk ? AppColors.success : (ans == null ? Colors.grey : AppColors.error), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Câu ${i + 1}: ${q.title}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (!isOk) Text('Đáp án đúng: ${q.targetText}', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                  if (!isOk && ans != null) Text('Bạn chọn: $ans', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  if (ans == null) const Text('Chưa trả lời', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
              ]),
            );
          }),
          const SizedBox(height: 20),

          // Action buttons
          if (_saved)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
              label: const Text('Xem Bảng Xếp Hạng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: const BorderSide(color: AppColors.primary)),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            icon: const Icon(Icons.home_rounded, color: AppColors.primary),
            label: const Text('Về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}
