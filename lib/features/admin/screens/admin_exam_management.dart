import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_paper.dart';
import '../../../services/firestore_service.dart';
import 'admin_exam_results_screen.dart';

// ignore_for_file: use_build_context_synchronously

/// Admin quản lý tổng thể đề thi: xóa / publish / unpublish. Không tạo bài thi.
class AdminExamManagement extends StatefulWidget {
  const AdminExamManagement({super.key});

  @override
  State<AdminExamManagement> createState() => _AdminExamManagementState();
}

class _AdminExamManagementState extends State<AdminExamManagement> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _confirmDelete(BuildContext context, ExamPaper paper) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa đề thi?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Xóa "${paper.title}" và toàn bộ câu hỏi? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirestoreService.deleteExamPaper(paper.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa đề thi!'), backgroundColor: Colors.red));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublished(BuildContext context, ExamPaper paper) async {
    try {
      await FirestoreService.setExamPaperPublished(paper.id, !paper.isPublished);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(paper.isPublished ? '📝 Đề thi đã chuyển về nháp!' : '✅ Đề thi đã được xuất bản!'),
          backgroundColor: paper.isPublished ? Colors.orange : Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý Đề Thi (Admin)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm tiêu đề, tác giả...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }))
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.allExamPapersStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Chưa có đề thi nào.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }
          var papers = FirestoreService.parseExamPapers(snap.data!);
          if (_searchQuery.isNotEmpty) {
            papers = papers.where((p) =>
              p.title.toLowerCase().contains(_searchQuery) ||
              p.creatorName.toLowerCase().contains(_searchQuery)).toList();
          }
          if (papers.isEmpty) {
            return const Center(child: Text('Không tìm thấy kết quả.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: papers.length,
            itemBuilder: (context, i) {
              final p = papers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: p.isPublished ? AppColors.surface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: !p.isPublished ? Border.all(color: Colors.orange.shade200) : null,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: p.isPublished
                            ? AppColors.primaryGradient
                            : [Colors.grey, Colors.blueGrey]),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(p.title,
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: p.isPublished ? AppColors.primary : Colors.grey))),
                        const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.isPublished ? Colors.green.shade50 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6)),
                            child: Text(p.isPublished ? 'Xuất bản' : 'Nháp',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                    color: p.isPublished ? Colors.green : Colors.orange))),
                      ]),
                      const SizedBox(height: 2),
                      Text('👤 ${p.creatorName.isNotEmpty ? p.creatorName : "Không rõ"}  ·  ⏱ ${p.durationMinutes} phút',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.bar_chart_rounded, color: Colors.blue),
                        tooltip: 'Xem kết quả',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdminExamResultsScreen(examPaperId: p.id, examTitle: p.title))),
                      ),
                      IconButton(
                        icon: Icon(p.isPublished ? Icons.unpublished_outlined : Icons.publish_outlined,
                            color: p.isPublished ? Colors.orange : Colors.green),
                        tooltip: p.isPublished ? 'Bỏ xuất bản' : 'Xuất bản',
                        onPressed: () => _togglePublished(context, p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'Xóa đề thi',
                        onPressed: () => _confirmDelete(context, p),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
