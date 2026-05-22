import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        totalScore: score,
        totalQuestions: total,
        correctAnswers: widget.correctCount,
        timeFinished: widget.timeSpentSeconds,
        testGroupId: 'general',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              AppColors.background,
            ],
            stops: [0.0, 0.2, 0.45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Kết Quả Bài Thi',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Score circle with glow
                    Center(child: Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.85), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 2, offset: const Offset(0, 8)),
                          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 50, spreadRadius: 8),
                        ],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('$score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white)),
                        const Text('điểm', style: TextStyle(fontSize: 16, color: Colors.white70)),
                      ]),
                    )).animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 24),

                    Text(
                      pct >= 0.8 ? '🎉 Xuất sắc!' : (pct >= 0.5 ? '👍 Khá tốt!' : '💪 Cố gắng hơn nhé!'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    const SizedBox(height: 24),

                    // Stats grid
                    Row(children: [
                      Expanded(child: _statCard('✅ Đúng', '${widget.correctCount}/$total', AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('❌ Sai', '${total - widget.correctCount}/$total', AppColors.error)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('⏱ Thời gian', _formatTime(widget.timeSpentSeconds), AppColors.accent)),
                    ]).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 400.ms),
                    const SizedBox(height: 24),

                    // Review answers
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
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOk ? AppColors.success.withValues(alpha: 0.4) : (ans == null ? AppColors.textLight.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.4)),
                            width: 1.5,
                          ),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          Icon(isOk ? Icons.check_circle_rounded : (ans == null ? Icons.remove_circle_outline : Icons.cancel_rounded),
                              color: isOk ? AppColors.success : (ans == null ? AppColors.textLight : AppColors.error), size: 22),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Câu ${i + 1}: ${q.title}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (!isOk) Text('Đáp án đúng: ${q.targetText}', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                            if (!isOk && ans != null) Text('Bạn chọn: $ans', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                            if (ans == null) const Text('Chưa trả lời', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                          ])),
                        ]),
                      ).animate().fadeIn(duration: 300.ms, delay: (500 + 50 * i).ms);
                    }),
                    const SizedBox(height: 24),

                    // Action buttons
                    if (_saved)
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.accentGradient),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                          icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
                          label: const Text('Xem Bảng Xếp Hạng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 600.ms)
                    else
                      const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                      icon: const Icon(Icons.home_rounded, color: AppColors.primary),
                      label: const Text('Về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.15)),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}
