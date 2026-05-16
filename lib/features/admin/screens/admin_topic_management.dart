import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';
import '../../../data/models/topic.dart';
import 'admin_sentence_management.dart';

class AdminTopicManagement extends StatefulWidget {
  const AdminTopicManagement({super.key});

  @override
  State<AdminTopicManagement> createState() => _AdminTopicManagementState();
}

class _AdminTopicManagementState extends State<AdminTopicManagement> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showTopicDialog({Topic? topic}) {
    final isEdit = topic != null;
    final titleCtrl = TextEditingController(text: isEdit ? topic.title : '');
    final descCtrl = TextEditingController(text: isEdit ? topic.description : '');
    bool isPublic = isEdit ? topic.isPublic : true;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Sửa Chủ Đề' : 'Thêm Chủ Đề Mới', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Tên chủ đề', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 14),
          TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(isPublic ? Icons.public : Icons.lock_outline, color: isPublic ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(isPublic ? 'Công khai' : 'Cá nhân', style: const TextStyle(fontWeight: FontWeight.bold))
              ]),
              Switch(value: isPublic, activeColor: Colors.green, onChanged: (v) => setD(() => isPublic = v)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: saving ? null : () async {
              if (titleCtrl.text.isEmpty) return;
              setD(() => saving = true);
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  if (isEdit) {
                    await FirestoreService.updateTopic(topic.id, {'title': titleCtrl.text.trim(), 'description': descCtrl.text.trim(), 'isPublic': isPublic});
                  } else {
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                    final authorName = userDoc.data()?['name'] ?? 'Admin';
                    await FirestoreService.createTopic({'title': titleCtrl.text.trim(), 'description': descCtrl.text.trim(), 'imageUrl': '', 'uid': user.uid, 'authorName': authorName, 'isPublic': isPublic});
                  }
                } catch (e) {
                  debugPrint('Lỗi: $e');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  void _confirmDeleteTopic(Topic topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa chủ đề?'),
        content: const Text('Tất cả câu hỏi bên trong sẽ bị xóa vĩnh viễn. Không thể hoàn tác!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.deleteTopic(topic.id);
            },
            child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        title: const Text('Quản lý Chủ đề bài học'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTopicDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm Chủ đề', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm chủ đề...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('topics').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('Chưa có chủ đề nào.', style: TextStyle(color: Colors.grey)));
                }

                var topics = FirestoreService.parseTopics(snap.data!);
                if (_searchQuery.isNotEmpty) {
                  topics = topics.where((t) => t.title.toLowerCase().contains(_searchQuery)).toList();
                }

                if (topics.isEmpty) return const Center(child: Text('Không tìm thấy chủ đề phù hợp.', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    final t = topics[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                        ),
                        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(t.isPublic ? Icons.public : Icons.lock, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(t.isPublic ? 'Công khai' : 'Riêng tư', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            )
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showTopicDialog(topic: t)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteTopic(t)),
                          ],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSentenceManagement(topic: t))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
