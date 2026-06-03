import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_paper.dart';
import '../../../data/models/exam_question.dart';
import '../../../services/pronunciation_service.dart';
import '../../shared/widgets/pronunciation_recorder_widget.dart';
import 'new_exam_result_screen.dart';

/// Màn hình làm bài thi kiểu Azota.
class NewExamScreen extends StatefulWidget {
  final ExamPaper paper;
  final List<ExamQuestion> questions;
  const NewExamScreen({
    super.key,
    required this.paper,
    required this.questions,
  });

  @override
  State<NewExamScreen> createState() => _NewExamScreenState();
}

class _NewExamScreenState extends State<NewExamScreen> {
  // State
  final Map<String, Map<String, dynamic>> _answers = {};
  int _idx = 0;
  bool _started = false;
  Timer? _timer;
  late int _remaining;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.paper.durationMinutes * 60;
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isAudioPlaying = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playQuestionAudio(String text) async {
    if (_isAudioPlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isAudioPlaying = false);
      return;
    }
    if (mounted) setState(() => _isAudioPlaying = true);
    try {
      final url =
          'http://116.118.2.137:8000/api/v1/tts?text=${Uri.encodeComponent(text)}';
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) setState(() => _isAudioPlaying = false);
    }
  }

  // ── Timer ──────────────────────────────────────

  void _startExam() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        _submit(autoSubmit: true);
      } else if (mounted) {
        setState(() => _remaining--);
      }
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── MCQ ────────────────────────────────────────

  void _selectMcq(ExamQuestion q, String option) {
    if (_answers.containsKey(q.id)) return; // Chỉ cho phép chọn đáp án 1 lần
    setState(() {
      _answers[q.id] = {
        'type': 'mcq',
        'selected': option,
        'isCorrect':
            option.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase(),
      };
    });
  }

  // ── Pronunciation callback ─────────────────────

  void _onPronResult(ExamQuestion q, PronunciationResult result) {
    setState(() {
      _answers[q.id] = {
        'type': 'pronunciation',
        'accuracy': result.accuracy,
        'isCorrect': result.passed,
      };
    });
  }

  // ── Submit ─────────────────────────────────────

  void _submit({bool autoSubmit = false}) {
    _timer?.cancel();
    int correct = 0;
    for (final q in widget.questions) {
      final ans = _answers[q.id];
      if (ans != null && ans['isCorrect'] == true) correct++;
    }
    final spent = widget.paper.durationMinutes * 60 - _remaining;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => NewExamResultScreen(
              paper: widget.paper,
              questions: widget.questions,
              answers: _answers,
              correctCount: correct,
              timeSpentSeconds: spent,
              isAutoSubmit: autoSubmit,
            ),
      ),
    );
  }

  void _confirmSubmit() {
    final answered = _answers.length;
    final total = widget.questions.length;
    final unanswered = total - answered;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Nộp bài?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📝 Tổng số câu: $total'),
                Text('✅ Đã làm: $answered'),
                if (unanswered > 0)
                  Text(
                    '⚠️ Chưa làm: $unanswered',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (unanswered == 0)
                  const Text(
                    '✅ Đã hoàn thành tất cả!',
                    style: TextStyle(color: Colors.green),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tiếp tục làm',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _submit();
                },
                child: const Text(
                  'Nộp bài',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // ══════════════════════════════════════════════════
  //  BUILD — Start Screen
  // ══════════════════════════════════════════════════

  Widget _buildStart() => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.primaryGradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.paper.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _infoRow(Icons.help_outline, '${widget.questions.length} câu hỏi'),
            const SizedBox(height: 10),
            _infoRow(
              Icons.timer_outlined,
              '${widget.paper.durationMinutes} phút',
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.star_outline, '10 điểm / câu đúng'),
            const SizedBox(height: 10),
            _infoRow(
              Icons.mic_rounded,
              'Phát âm: thu âm & chấm AI (≥80% = đạt)',
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _startExam,
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                label: const Text(
                  'Bắt đầu làm bài',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _infoRow(IconData icon, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ),
    ],
  );

  // ══════════════════════════════════════════════════
  //  BUILD — Exam (Azota-style)
  // ══════════════════════════════════════════════════

  Widget _buildExam() {
    final q = widget.questions[_idx];
    final isMcq = q.type == ExamQuestionType.mcq;
    final answered = _answers.length;
    final total = widget.questions.length;
    final timerColor =
        _remaining < 60
            ? Colors.red
            : (_remaining < 300 ? Colors.orange : Colors.white);

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AZOTA TOP BAR ──
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (_remaining < 60 ? Colors.red : Colors.white)
                      .withValues(alpha: _remaining < 60 ? 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: timerColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(_remaining),
                      style: TextStyle(
                        color: timerColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Tên bài thi
              Flexible(
                child: Text(
                  widget.paper.title,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // Nút nộp bài
              TextButton(
                onPressed: _confirmSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Nộp bài',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Progress bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: answered / total,
            backgroundColor: Colors.white24,
            color: AppColors.accent,
            minHeight: 6,
          ),
        ),
      ),

      body: Column(
        children: [
          // ── BẢNG SỐ CÂU (Azota question grid) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(total, (i) {
                  final qId = widget.questions[i].id;
                  final isAnswered = _answers.containsKey(qId);
                  final isCurrent = i == _idx;
                  Color bg;
                  Color fg;
                  if (isCurrent) {
                    bg = AppColors.primary;
                    fg = Colors.white;
                  } else if (isAnswered) {
                    bg = AppColors.accent;
                    fg = Colors.white;
                  } else {
                    bg = Colors.grey.shade200;
                    fg = Colors.grey.shade700;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _idx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              isCurrent
                                  ? Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  )
                                  : null,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── NỘI DUNG CÂU HỎI ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header câu hỏi
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Badge loại
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isMcq
                                    ? AppColors.accent
                                    : AppColors.primary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isMcq ? '🎧 Luyện nghe' : '🎙 Phát âm',
                            style: TextStyle(
                              color:
                                  isMcq ? AppColors.accent : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Số câu
                        Text(
                          'Câu ${_idx + 1} / $total',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Nội dung
                        if (isMcq) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                const Text(
                                  'Nhấn vào nút bên dưới để nghe âm thanh',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => _playQuestionAudio(q.targetText),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          _isAudioPlaying
                                              ? AppColors.accent
                                              : AppColors.primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isAudioPlaying
                                                  ? AppColors.accent
                                                  : AppColors.primary)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isAudioPlaying
                                          ? Icons.volume_up_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Pronunciation: hiển thị targetText nổi bật
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Hãy đọc câu sau:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  q.targetText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // MCQ options
                  if (isMcq) ..._buildMcqOptions(q),

                  // Pronunciation recorder (dùng chung widget)
                  if (!isMcq) ...[
                    PronunciationRecorderWidget(
                      key: ValueKey('pron_${q.id}'),
                      targetText: q.targetText,
                      recordId: q.id,
                      initialResult:
                          _answers.containsKey(q.id) &&
                                  _answers[q.id]!['type'] == 'pronunciation'
                              ? PronunciationResult(
                                targetText: q.targetText,
                                recognizedText: '',
                                accuracy:
                                    _answers[q.id]!['accuracy'] as int? ?? 0,
                                passed:
                                    _answers[q.id]!['isCorrect'] as bool? ??
                                    false,
                              )
                              : null,
                      onResult: (result) => _onPronResult(q, result),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ── BOTTOM NAV (Prev / Grid / Next) ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // Trước
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _idx > 0 ? () => setState(() => _idx--) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text('Trước'),
              ),
            ),
            const SizedBox(width: 12),
            // Grid tổng
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.primary,
                ),
                onPressed: _showGrid,
                tooltip: 'Danh sách câu',
              ),
            ),
            const SizedBox(width: 12),
            // Tiếp / Nộp bài
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _idx < total - 1
                        ? () => setState(() => _idx++)
                        : _confirmSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  _idx < total - 1
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.check_rounded,
                  size: 16,
                ),
                label: Text(
                  _idx < total - 1 ? 'Tiếp theo' : 'Nộp bài',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMcqOptions(ExamQuestion q) {
    final ansData = _answers[q.id];
    final hasAnswered = ansData != null;
    final selected = ansData?['selected'] as String?;
    final correctAns = q.correctAnswer.trim().toLowerCase();

    return q.options.asMap().entries.map((e) {
      final i = e.key;
      final opt = e.value;
      final letter = String.fromCharCode(65 + i);

      final isSelected = selected == opt;
      final isThisOptionCorrect = opt.trim().toLowerCase() == correctAns;

      Color bgColor = AppColors.surface;
      Color borderColor = Colors.grey.shade200;
      Color textColor = AppColors.textPrimary;
      IconData? icon;
      Color iconColor = Colors.transparent;

      if (hasAnswered) {
        if (isThisOptionCorrect) {
          bgColor = Colors.green.shade50;
          borderColor = Colors.green;
          textColor = Colors.green.shade700;
          icon = Icons.check_circle_rounded;
          iconColor = Colors.green;
        } else if (isSelected) {
          bgColor = Colors.red.shade50;
          borderColor = Colors.red;
          textColor = Colors.red.shade700;
          icon = Icons.cancel_rounded;
          iconColor = Colors.red;
        } else {
          textColor = Colors.grey;
        }
      }

      return GestureDetector(
        onTap: () => _selectMcq(q, opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      hasAnswered && (isThisOptionCorrect || isSelected)
                          ? iconColor
                          : Colors.grey.shade100,
                  border: Border.all(
                    color:
                        hasAnswered && (isThisOptionCorrect || isSelected)
                            ? iconColor
                            : Colors.grey.shade300,
                  ),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          hasAnswered && (isThisOptionCorrect || isSelected)
                              ? Colors.white
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        (hasAnswered && (isThisOptionCorrect || isSelected))
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, color: iconColor, size: 22),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ── Grid bottom sheet ──────────────────────────

  void _showGrid() {
    final total = widget.questions.length;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Danh sách câu hỏi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã làm: ${_answers.length}/$total',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: total,
                  itemBuilder: (_, i) {
                    final qId = widget.questions[i].id;
                    final isAnswered = _answers.containsKey(qId);
                    final isCurrent = i == _idx;
                    Color bg;
                    if (isCurrent) {
                      bg = AppColors.primary;
                    } else if (isAnswered) {
                      bg = AppColors.accent;
                    } else {
                      bg = Colors.grey.shade200;
                    }
                    return GestureDetector(
                      onTap: () {
                        setState(() => _idx = i);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color:
                                  isCurrent || isAnswered
                                      ? Colors.white
                                      : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legend(AppColors.primary, 'Đang làm'),
                    const SizedBox(width: 16),
                    _legend(AppColors.accent, 'Đã làm'),
                    const SizedBox(width: 16),
                    _legend(Colors.grey.shade200, 'Chưa làm'),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _legend(Color c, String label) => Row(
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) => _started ? _buildExam() : _buildStart();
}
