import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';

// ignore_for_file: use_build_context_synchronously

class AdminUserManagement extends StatefulWidget {
  const AdminUserManagement({super.key});

  @override
  State<AdminUserManagement> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends State<AdminUserManagement> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _confirmDelete(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa tài khoản?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa tài khoản của "$name"?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.deleteUserDoc(uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa tài khoản!'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String uid, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    String selectedRole = (data['role'] as String?) ?? 'user';
    final String userEmail = data['email'] ?? '';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sửa thông tin User', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Avatar preview
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: (data['avatarUrl'] ?? data['photoUrl'] ?? '').isNotEmpty
                  ? NetworkImage(data['avatarUrl'] ?? data['photoUrl'] ?? '')
                  : null,
              child: (data['avatarUrl'] ?? data['photoUrl'] ?? '').isEmpty
                  ? Text(nameCtrl.text.isNotEmpty ? nameCtrl.text[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100], borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings_outlined, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Vai trò:', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                DropdownButton<String>(
                  value: selectedRole,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(color: Color(0xFFf7971e)))),
                  ],
                  onChanged: (v) { if (v != null) setD(() => selectedRole = v); },
                ),
              ]),
            ),
            if (userEmail.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_reset, color: Colors.white, size: 20),
                  label: const Text('Gửi Email Đặt Lại Mật Khẩu', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('✅ Đã gửi email đặt lại MK tới $userEmail'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Lỗi gửi email: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              const Text('Người dùng sẽ nhận được email có link để tự đổi mật khẩu an toàn.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
            ]
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: saving ? null : () async {
              setD(() => saving = true);
              try {
                // Update basic user info in Firestore
                await FirestoreService.updateUserByAdmin(uid, {
                  'name': nameCtrl.text.trim(),
                  'role': selectedRole,
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Đã cập nhật thông tin!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (ctx.mounted) {
                  setD(() => saving = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý Người dùng'),
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
                hintText: 'Tìm tên, email...',
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
      body: StreamBuilder(
        stream: FirestoreService.allUsersStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Không có người dùng nào.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }
          var users = snap.data!.docs;
          if (_searchQuery.isNotEmpty) {
            users = users.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final name = (d['name'] ?? '').toString().toLowerCase();
              final email = (d['email'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || email.contains(_searchQuery);
            }).toList();
          }
          if (users.isEmpty) {
            return const Center(child: Text('Không tìm thấy kết quả.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final data = users[i].data() as Map<String, dynamic>;
              final uid = users[i].id;
              final name = data['name'] ?? 'Không rõ';
              final email = data['email'] ?? '';
              final score = data['totalScore'] ?? 0;
              final isAdmin = (data['role'] ?? 'user') == 'admin';
              final avatarUrl = data['avatarUrl'] ?? data['photoUrl'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    backgroundColor: isAdmin ? const Color(0xFFf7971e).withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.12),
                    child: avatarUrl.isEmpty
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: isAdmin ? const Color(0xFFf7971e) : AppColors.primary,
                                fontWeight: FontWeight.bold, fontSize: 18))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary))),
                      if (isAdmin) ...[const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFf7971e).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Text('ADMIN', style: TextStyle(fontSize: 10, color: Color(0xFFf7971e), fontWeight: FontWeight.bold)))],
                    ]),
                    const SizedBox(height: 3),
                    Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.star_rounded, size: 14, color: AppColors.accent), const SizedBox(width: 3),
                      Text('$score điểm', style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600))]),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
                      tooltip: 'Sửa thông tin',
                      onPressed: () => _showEditDialog(context, uid, data),
                    ),
                    if (!isAdmin) IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Xóa user',
                      onPressed: () => _confirmDelete(context, uid, name),
                    ),
                  ]),
                ])),
              );
            },
          );
        },
      ),
    );
  }
}
