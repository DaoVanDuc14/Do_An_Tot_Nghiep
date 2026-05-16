import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_user_management.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Đăng xuất',
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C3E50), Color(0xFF00B4D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2C3E50).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white70, size: 40),
                  const SizedBox(height: 12),
                  const Text('Xin chào, Quản trị viên!',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(user?.email ?? 'Admin',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // STATS ROW
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'Topics', Icons.menu_book_rounded, 'topics',
                        const Color(0xFF2C3E50))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'Users', Icons.people_alt_rounded, 'users',
                        const Color(0xFF8E54E9))),
              ],
            ),
            const SizedBox(height: 28),

            const Text('Quản lý hệ thống',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50))),
            const SizedBox(height: 16),

            _buildMenuCard(
              context,
              icon: Icons.people_alt_rounded,
              title: 'Quản lý Người dùng',
              subtitle: 'Xem danh sách, điểm số và xóa tài khoản',
              gradient: const [Color(0xFF4776E6), Color(0xFF8E54E9)],
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminUserManagement())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, IconData icon, String collection, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text('$count',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2C3E50))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF7F8C8D))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFBDC3C7), size: 28),
          ],
        ),
      ),
    );
  }
}

