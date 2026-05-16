import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';
import '../../../data/models/topic.dart';
import '../../../data/models/sentence.dart';

class AdminSentenceManagement extends StatefulWidget {
  final Topic topic;
  const AdminSentenceManagement({super.key, required this.topic});

  @override
  State<AdminSentenceManagement> createState() => _AdminSentenceManagementState();
}

class _AdminSentenceManagementState extends State<AdminSentenceManagement> {

  void _showSentenceDialog({Sentence? sentence}) {
    final isEdit = sentence != null;
    final vnCtrl = TextEditingController(text: isEdit ? sentence.vietnamese : '');
    final enCtrl = TextEditingController(text: isEdit ? sentence.english : '');
    final audioCtrl = TextEditingController(text: isEdit ? sentence.audioUrl : '');
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Sửa Câu/Từ' : 'Thêm Câu/Từ', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: vnCtrl, decoration: InputDecoration(labelText: 'Tiếng Việt', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 14),
            TextField(controller: enCtrl, decoration: InputDecoration(labelText: 'Tiếng Anh', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 14),
            TextField(controller: audioCtrl, decoration: InputDecoration(labelText: 'Audio URL (tùy chọn)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: saving ? null : () async {
              if (vnCtrl.text.isEmpty || enCtrl.text.isEmpty) return;
              setD(() => saving = true);
              try {
                if (isEdit) {
                  await FirestoreService.updateSentence(sentence.id, {
                    'vietnamese': vnCtrl.text.trim(),
                    'english': enCtrl.text.trim(),
                    'audioUrl': audioCtrl.text.trim(),
                  });
                } else {
                  await FirestoreService.createSentence({
                    'topicId': widget.topic.id,
                    'vietnamese': vnCtrl.text.trim(),
                    'english': enCtrl.text.trim(),
                    'audioUrl': audioCtrl.text.trim(),
                  });
                }
              } catch (e) {
                debugPrint('Lỗi: $e');
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  void _confirmDeleteSentence(Sentence sentence) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Câu/Từ?'),
        content: const Text('Bạn có chắc muốn xóa câu này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.deleteSentence(sentence.id);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chi tiết: ${widget.topic.title}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSentenceDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm câu/từ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.sentencesStream(widget.topic.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.speaker_notes_off_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có câu/từ nào trong chủ đề này.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final sentences = FirestoreService.parseSentences(snap.data!);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 16),
            itemCount: sentences.length,
            itemBuilder: (context, index) {
              final s = sentences[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(s.vietnamese, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                  subtitle: Text(s.english, style: const TextStyle(color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showSentenceDialog(sentence: s)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteSentence(s)),
                    ],
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
