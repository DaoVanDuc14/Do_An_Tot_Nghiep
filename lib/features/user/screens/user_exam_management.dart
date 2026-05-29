import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_paper.dart';
import '../../../data/models/exam_question.dart';
import '../../../services/firestore_service.dart';
import 'new_exam_screen.dart';

// ignore_for_file: use_build_context_synchronously

// ══════════════════════════════════════════
// Danh sách bài thi của User
// ══════════════════════════════════════════
class UserExamManagement extends StatelessWidget {
  const UserExamManagement({super.key});

  Future<void> _showPaperDialog(
    BuildContext context, {
    ExamPaper? paper,
  }) async {
    final isEdit = paper != null;
    final titleCtrl = TextEditingController(text: isEdit ? paper.title : '');
    final durCtrl = TextEditingController(
      text: isEdit ? '${paper.durationMinutes}' : '30',
    );
    bool saving = false;
    String? titleForNav;

    final newExamId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setD) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    isEdit ? 'Sửa Đề Thi' : 'Tạo Đề Thi Mới',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Tiêu đề đề thi',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Thời gian làm bài (phút)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text(
                        'Hủy',
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
                      onPressed:
                          saving
                              ? null
                              : () async {
                                if (titleCtrl.text.trim().isEmpty) return;
                                setD(() => saving = true);
                                try {
                                  final user =
                                      FirebaseAuth.instance.currentUser!;
                                  final userDoc =
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .get();
                                  final creatorName =
                                      (userDoc.data()?['name'] as String?) ??
                                      user.email ??
                                      'Ẩn danh';
                                  if (isEdit) {
                                    await FirestoreService.updateExamPaper(
                                      paper.id,
                                      {
                                        'title': titleCtrl.text.trim(),
                                        'duration_minutes':
                                            int.tryParse(durCtrl.text) ?? 30,
                                      },
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } else {
                                    final data = {
                                      'title': titleCtrl.text.trim(),
                                      'duration_minutes':
                                          int.tryParse(durCtrl.text) ?? 30,
                                      'creatorId': user.uid,
                                      'creatorName': creatorName,
                                      'isPublished': false,
                                    };
                                    titleForNav = titleCtrl.text.trim();
                                    final ref =
                                        await FirestoreService.createExamPaper(
                                          data,
                                        );
                                    if (ctx.mounted) Navigator.pop(ctx, ref.id);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Lỗi: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    setD(() => saving = false);
                                  }
                                }
                              },
                      child:
                          saving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                isEdit ? 'Lưu' : 'Tạo & Thêm câu hỏi',
                                style: const TextStyle(color: Colors.white),
                              ),
                    ),
                  ],
                ),
          ),
    );

    if (newExamId != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => UserExamQuestionsScreen(
                examPaperId: newExamId,
                examTitle: titleForNav ?? '',
                allowStartExam: true,
              ),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, ExamPaper paper) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Xóa đề thi?',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text('Xóa "${paper.title}" và toàn bộ câu hỏi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirestoreService.deleteExamPaper(paper.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Xóa', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _togglePublish(BuildContext context, ExamPaper p) async {
    await FirestoreService.setExamPaperPublished(p.id, !p.isPublished);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.isPublished ? '📝 Đã chuyển về nháp' : '✅ Đã xuất bản bài thi!',
          ),
          backgroundColor: p.isPublished ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bài thi của tôi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaperDialog(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tạo đề thi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.myExamPapersStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa tạo đề thi nào.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showPaperDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Tạo đề đầu tiên',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }
          final papers = FirestoreService.parseExamPapers(snap.data!);
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 100,
            ),
            itemCount: papers.length,
            itemBuilder: (context, i) {
              final p = papers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            p.isPublished
                                ? AppColors.primaryGradient
                                : [Colors.grey, Colors.blueGrey],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              p.isPublished
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.isPublished ? 'Đã xuất bản' : 'Nháp',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: p.isPublished ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '⏱ ${p.durationMinutes} phút',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'questions') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => UserExamQuestionsScreen(
                                  examPaperId: p.id,
                                  examTitle: p.title,
                                ),
                          ),
                        );
                      }
                      if (v == 'edit') _showPaperDialog(context, paper: p);
                      if (v == 'publish') _togglePublish(context, p);
                      if (v == 'share') {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                'https://vku-vietnamese-learning.web.app/?examId=${p.id}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔗 Đã sao chép link!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      if (v == 'delete') _confirmDelete(context, p);
                    },
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'questions',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  size: 18,
                                  color: AppColors.accent,
                                ),
                                SizedBox(width: 8),
                                Text('Câu hỏi'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Sửa'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'publish',
                            child: Row(
                              children: [
                                Icon(
                                  p.isPublished
                                      ? Icons.unpublished
                                      : Icons.publish,
                                  size: 18,
                                  color:
                                      p.isPublished
                                          ? Colors.orange
                                          : Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  p.isPublished ? 'Bỏ xuất bản' : 'Xuất bản',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.share,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8),
                                Text('Chia sẻ'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Xóa',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════
// Quản lý câu hỏi trong bài thi
// ══════════════════════════════════════════
class UserExamQuestionsScreen extends StatefulWidget {
  final String examPaperId;
  final String examTitle;
  final bool allowStartExam;
  const UserExamQuestionsScreen({
    super.key,
    required this.examPaperId,
    required this.examTitle,
    this.allowStartExam = false,
  });

  @override
  State<UserExamQuestionsScreen> createState() =>
      _UserExamQuestionsScreenState();
}

class _UserExamQuestionsScreenState extends State<UserExamQuestionsScreen> {
  void _showQuestionDialog(BuildContext context, {ExamQuestion? q}) {
    final isEdit = q != null;
    final targetCtrl = TextEditingController(text: isEdit ? q.targetText : '');
    final optCtrls =
        isEdit && q.options.isNotEmpty
            ? q.options.map((o) => TextEditingController(text: o)).toList()
            : List.generate(4, (_) => TextEditingController());
    ExamQuestionType selType = isEdit ? q.type : ExamQuestionType.mcq;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setD) {
              Future<void> save() async {
                final target = targetCtrl.text.trim();
                if (target.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập nội dung!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (selType == ExamQuestionType.mcq) {
                  final opts =
                      optCtrls
                          .map((c) => c.text.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                  if (opts.length < 2) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Cần ít nhất 2 lựa chọn!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                }
                setD(() => saving = true);
                try {
                  final opts =
                      selType == ExamQuestionType.mcq
                          ? optCtrls
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .toList()
                          : <String>[];
                  int orderIndex = isEdit ? q.orderIndex : 0;
                  if (!isEdit) {
                    try {
                      final existing =
                          await FirebaseFirestore.instance
                              .collection('exam_questions')
                              .where(
                                'examPaperId',
                                isEqualTo: widget.examPaperId,
                              )
                              .get();
                      orderIndex = existing.docs.length;
                    } catch (_) {}
                  }
                  final data = {
                    'examPaperId': widget.examPaperId,
                    'type':
                        selType == ExamQuestionType.pronunciation
                            ? 'pronunciation'
                            : 'mcq',
                    'targetText': target,
                    'options': opts,
                    'correctAnswer':
                        selType == ExamQuestionType.mcq ? target : '',
                    'orderIndex': orderIndex,
                  };
                  if (isEdit) {
                    await FirestoreService.updateExamQuestion(q.id, data);
                  } else {
                    await FirestoreService.createExamQuestion(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit ? '✅ Đã cập nhật!' : '✅ Đã thêm câu hỏi!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted)
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('❌ $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                } finally {
                  if (ctx.mounted) setD(() => saving = false);
                }
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  isEdit ? 'Sửa Câu Hỏi' : 'Thêm Câu Hỏi',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Loại câu hỏi
                      const Text(
                        'Loại câu hỏi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _typeChip(
                            setD,
                            'Luyện nghe',
                            ExamQuestionType.mcq,
                            selType,
                            AppColors.accent,
                            () => setD(() => selType = ExamQuestionType.mcq),
                          ),
                          const SizedBox(width: 10),
                          _typeChip(
                            setD,
                            'Phát âm',
                            ExamQuestionType.pronunciation,
                            selType,
                            AppColors.primary,
                            () => setD(
                              () => selType = ExamQuestionType.pronunciation,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nội dung câu hỏi
                      TextField(
                        controller: targetCtrl,
                        decoration: InputDecoration(
                          labelText:
                              selType == ExamQuestionType.pronunciation
                                  ? 'Câu cần đọc (VD: Xin chào)'
                                  : 'Nội dung câu nói (AI sẽ đọc lên)',
                          helperText:
                              selType == ExamQuestionType.pronunciation
                                  ? 'Người thi sẽ thu âm đọc câu này'
                                  : 'Văn bản bị ẩn, người thi sẽ nghe âm thanh',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      // MCQ fields
                      if (selType == ExamQuestionType.mcq) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Các lựa chọn:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(
                          4,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: optCtrls[i],
                              decoration: InputDecoration(
                                labelText:
                                    'Lựa chọn ${String.fromCharCode(65 + i)}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Pronunciation info
                      if (selType == ExamQuestionType.pronunciation) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI sẽ tự động chấm điểm phát âm.\nĐẠT khi accuracy ≥ 80%.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text(
                      'Hủy',
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
                    onPressed: saving ? null : save,
                    child:
                        saving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Lưu',
                              style: TextStyle(color: Colors.white),
                            ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _typeChip(
    StateSetter setD,
    String label,
    ExamQuestionType type,
    ExamQuestionType current,
    Color activeColor,
    VoidCallback onTap,
  ) {
    final isActive = current == type;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              type == ExamQuestionType.mcq ? '🎧 $label' : '🎙 $label',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startExam(BuildContext context) async {
    try {
      final snap =
          await FirestoreService.examQuestionsStream(widget.examPaperId).first;
      final questions = FirestoreService.parseExamQuestions(snap);
      if (!context.mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Chưa có câu hỏi nào!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final paper = await FirestoreService.getExamPaperById(widget.examPaperId);
      if (!context.mounted || paper == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewExamScreen(paper: paper, questions: questions),
        ),
      );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.examTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.allowStartExam)
            TextButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Thi thử',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _startExam(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuestionDialog(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Thêm câu hỏi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.examQuestionsStream(widget.examPaperId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có câu hỏi nào.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          final questions = FirestoreService.parseExamQuestions(snap.data!);
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 100,
            ),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i];
              final isPron = q.type == ExamQuestionType.pronunciation;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isPron ? AppColors.primary : AppColors.accent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isPron ? AppColors.primary : AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPron ? '🎙 Phát âm' : '🎧 Luyện nghe',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  isPron ? AppColors.primary : AppColors.accent,
                            ),
                          ),
                          Text(
                            q.targetText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isPron && q.correctAnswer.isNotEmpty)
                            Text(
                              'Đáp án: ${q.correctAnswer}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _showQuestionDialog(context, q: q);
                        if (v == 'delete') {
                          FirestoreService.deleteExamQuestion(q.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã xóa!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Sửa'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Xóa',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
