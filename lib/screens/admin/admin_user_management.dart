import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserManagement extends StatelessWidget {
  const AdminUserManagement({super.key});

  void _confirmDeleteUser(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa tài khoản?',
            style: TextStyle(
                color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
        content: Text(
            'Bạn có chắc muốn xóa tài khoản của "$name" không?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Đã xóa tài khoản!'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Quản lý Người dùng',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2C3E50)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Không có người dùng nào.',
                    style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;
              final name = data['name'] ?? 'Không rõ';
              final email = data['email'] ?? '';
              final score = data['totalScore'] ?? 0;
              final role = data['role'] ?? 'user';
              final isAdmin = role == 'admin';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // AVATAR
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isAdmin
                                ? [
                                    const Color(0xFFf7971e),
                                    const Color(0xFFffd200)
                                  ]
                                : [
                                    const Color(0xFF2C3E50),
                                    const Color(0xFF00B4D8)
                                  ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // INFO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF2C3E50))),
                                const SizedBox(width: 8),
                                if (isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFf7971e)
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    child: const Text('ADMIN',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFf7971e),
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(email,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF7F8C8D))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 15, color: Color(0xFF00B4D8)),
                                const SizedBox(width: 4),
                                Text('$score điểm',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF00B4D8),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // DELETE (chỉ xóa user thường, không xóa admin)
                      if (!isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          tooltip: 'Xóa user',
                          onPressed: () =>
                              _confirmDeleteUser(context, uid, name),
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

