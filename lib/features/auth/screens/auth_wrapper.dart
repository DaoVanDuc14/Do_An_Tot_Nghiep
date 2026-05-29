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
  final User? initialUser;
  final String initialRole;
  final bool hasInitialData;

  const AuthWrapper({
    super.key,
    this.initialUser,
    this.initialRole = 'user',
    this.hasInitialData = false,
  });

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
    if (widget.hasInitialData) {
      _user = widget.initialUser;
      _role = widget.initialRole;
      _loading = false;
    }
    _authSub = FirebaseAuth.instance.userChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _user = null;
        _role = 'user';
        _loading = false;
      });
      return;
    }
    // Tránh fetch role lại nếu user không đổi (ví dụ khi gọi user.reload() làm trigger userChanges)
    if (_user?.uid == user.uid && !_loading) {
      setState(() {
        _user = user;
      });
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
        setState(() {
          _user = user;
          _role = role;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint(
        '⚠️ AuthWrapper: Lỗi hoặc timeout khi lấy role, mặc định user. Error: $e',
      );
      if (mounted) {
        setState(() {
          _user = user;
          _role = 'user';
          _loading = false;
        });
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
    // Loading state: hiển thị indicator nhẹ (splash đã hiển thị trước đó rồi)
    if (_loading) return _buildLoadingScreen();
    if (_user == null) return const AuthScreen();

    // Bắt buộc xác minh email (trừ admin)
    // Người dùng đăng nhập bằng Google mặc định emailVerified = true
    if (!_user!.emailVerified && _role != 'admin') {
      return const VerifyEmailScreen();
    }

    if (_role == 'admin') return const AdminDashboard();
    return const HomeScreen();
  }

  Widget _buildLoadingScreen() {
    // Nền navy đậm khớp với splash, tránh flash trắng
    return const Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SizedBox.shrink(),
    );
  }
}
