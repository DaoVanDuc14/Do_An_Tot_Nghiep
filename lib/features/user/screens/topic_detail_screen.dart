import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/topic.dart';
import '../../../data/models/sentence.dart';
import '../../../services/firestore_service.dart';
import 'practice_screen.dart';

class TopicDetailScreen extends StatelessWidget {
  final Topic topic;
  const TopicDetailScreen({super.key, required this.topic});

  Color _scoreColor(int score) {
    if (score == 0) return Colors.grey;
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  void _showSentenceDialog(BuildContext context, {Sentence? sentence}) {
    final isEdit = sentence != null;
    final vnCtrl = TextEditingController(text: isEdit ? sentence.vietnamese : '');
    final enCtrl = TextEditingController(text: isEdit ? sentence.english : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Sửa Câu Nói' : 'Thêm Câu Nói', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: vnCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Tiếng Việt', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: enCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Tiếng Anh (tùy chọn)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (vnCtrl.text.isNotEmpty) {
                if (isEdit) {
                  await FirestoreService.updateSentence(sentence.id, {'vietnamese': vnCtrl.text.trim(), 'english': enCtrl.text.trim()});
                } else {
                  await FirestoreService.createSentence({'vietnamese': vnCtrl.text.trim(), 'english': enCtrl.text.trim(), 'topicId': topic.id, 'audioUrl': ''});
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Sentence sentence) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa câu này?'),
        content: const Text('Bạn có chắc muốn xóa câu nói này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async { Navigator.pop(ctx); await FirestoreService.deleteSentence(sentence.id); },
            child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user?.uid == topic.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        title: Text(topic.title),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey[200], height: 1)),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: () => _showSentenceDialog(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.sentencesStream(topic.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(child: Text(isOwner ? 'Chưa có câu hỏi nào.\nHãy bấm nút + để thêm nhé!' : 'Tác giả chưa cập nhật câu hỏi.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)));
          }
          final sentences = FirestoreService.parseSentences(snap.data!);
          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
            physics: const BouncingScrollPhysics(),
            itemCount: sentences.length,
            itemBuilder: (context, index) {
              final s = sentences[index];
              return StreamBuilder<DocumentSnapshot>(
                stream: FirestoreService.progressStream(user?.uid ?? '', s.id),
                builder: (context, progSnap) {
                  int score = 0;
                  if (progSnap.hasData && progSnap.data!.exists) score = progSnap.data!['score'] ?? 0;
                  final color = _scoreColor(score);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PracticeScreen(sentence: s))),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Container(height: 44, width: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.play_arrow_rounded, color: color, size: 28)),
                            const SizedBox(width: 16),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.vietnamese, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              if (s.english.isNotEmpty) Text(s.english, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ])),
                            if (isOwner)
                              Row(children: [
                                _scoreCircle(score, color),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') { _showSentenceDialog(context, sentence: s); }
                                    else if (v == 'delete') { _confirmDelete(context, s); }
                                  },
                                  itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Sửa câu này')), PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red)))],
                                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                                ),
                              ])
                            else
                              _scoreCircle(score, color),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _scoreCircle(int score, Color color) => SizedBox(width: 48, height: 48, child: Stack(fit: StackFit.expand, children: [
    CircularProgressIndicator(value: score / 100, backgroundColor: Colors.grey[100], color: color, strokeWidth: 4, strokeCap: StrokeCap.round),
    Center(child: Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))),
  ]));
}
