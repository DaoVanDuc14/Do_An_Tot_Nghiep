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
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchCtrl.clear();
        _searchQuery = '';
      }
    });
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
              Switch(value: isPublic, activeThumbColor: Colors.green, onChanged: (v) => setD(() => isPublic = v)),
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
        centerTitle: true,
        title: const Text('Quản lý Chủ đề', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
            onPressed: _toggleSearch,
          ),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm chủ đề...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                              }))
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showTopicDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Thêm Chủ đề', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('topics').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Chưa có chủ đề nào.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          var topics = FirestoreService.parseTopics(snap.data!);
          if (_searchQuery.isNotEmpty) {
            topics = topics.where((t) => t.title.toLowerCase().contains(_searchQuery)).toList();
          }

          if (topics.isEmpty) {
            return const Center(child: Text('Không tìm thấy chủ đề phù hợp.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 16),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final t = topics[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Header row: icon + info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: AppColors.accentGradient),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(t.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: t.isPublic ? Colors.green.shade50 : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(t.isPublic ? Icons.public : Icons.lock_outline, size: 12,
                                            color: t.isPublic ? Colors.green : Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(t.isPublic ? 'Công khai' : 'Riêng tư',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                              color: t.isPublic ? Colors.green : Colors.orange)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (t.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(t.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(t.authorName.isNotEmpty ? t.authorName : 'Không rõ',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1, color: Colors.black12),
                      const SizedBox(height: 4),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                              icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                              label: const Text('Chi tiết', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSentenceManagement(topic: t))),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                              label: const Text('Sửa', style: TextStyle(color: Colors.blue, fontSize: 13)),
                              onPressed: () => _showTopicDialog(topic: t),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              label: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                              onPressed: () => _confirmDeleteTopic(t),
                            ),
                          ),
                        ],
                      ),
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
