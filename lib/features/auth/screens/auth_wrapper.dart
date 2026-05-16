import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../admin/screens/admin_dashboard.dart';
import '../../user/screens/home_screen.dart';
import 'auth_screen.dart';
import 'verify_email_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

/// StatefulWidget approach: lắng nghe auth state, sau đó fetch role 1 lần
/// Tránh nested StreamBuilder gây race condition.
class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  String _role = 'user';
  bool _loading = true;
  late StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.userChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;
    if (user == null) {
      setState(() { _user = null; _role = 'user'; _loading = false; });
      return;
    }
    // Tránh fetch role lại nếu user không đổi (ví dụ khi gọi user.reload() làm trigger userChanges)
    if (_user?.uid == user.uid && !_loading) {
      setState(() { _user = user; });
      return;
    }
    // Fetch role từ Firestore (có timeout để tránh treo vô hạn)
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = doc.data();
      final role = (data?['role'] as String?) ?? 'user';
      debugPrint('✅ AuthWrapper: uid=${user.uid} role=$role');
      if (mounted) {
        setState(() { _user = user; _role = role; _loading = false; });
      }
    } catch (e) {
      debugPrint('⚠️ AuthWrapper: Lỗi hoặc timeout khi lấy role, mặc định user. Error: $e');
      if (mounted) {
        setState(() { _user = user; _role = 'user'; _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    if (_user == null) return const AuthScreen();

    // Bắt buộc xác minh email (trừ admin)
    // Người dùng đăng nhập bằng Google mặc định emailVerified = true
    if (!_user!.emailVerified && _role != 'admin') {
      return const VerifyEmailScreen();
    }

    if (_role == 'admin') return const AdminDashboard();
    return const HomeScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, color: Colors.white, size: 64),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text('Đang tải...', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
