import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'features/shared/screens/splash_screen.dart';
import 'features/auth/screens/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Đặt status bar trong suốt để splash đẹp hơn
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Học Tiếng Việt AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Splash Screen hiển thị NGAY khi mở app, trước mọi thứ
      home: const _AppEntry(),
    );
  }
}

/// Entry point: hiển thị Splash Screen ≥ 2.5s
/// Trong khi splash chạy, đồng thời kiểm tra auth + fetch role.
/// Khi splash xong → chuyển thẳng tới đúng màn hình, không qua loading trắng.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;

  // Kết quả auth được pre-fetch trong lúc splash hiển thị
  User? _user;
  String _role = 'user';
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    // Bắt đầu pre-fetch auth song song với splash
    _prefetchAuth();
  }

  /// Lấy trạng thái đăng nhập + role trong nền, chạy song song với splash animation
  Future<void> _prefetchAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _user = null;
          _role = 'user';
          _authReady = true;
        });
      }
      return;
    }

    // Reload user để có emailVerified mới nhất
    try {
      await user.reload();
    } catch (_) {}

    final freshUser = FirebaseAuth.instance.currentUser;

    // Fetch role từ Firestore
    String role = 'user';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(freshUser?.uid)
          .get()
          .timeout(const Duration(seconds: 6));
      role = (doc.data()?['role'] as String?) ?? 'user';
    } catch (e) {
      debugPrint('⚠️ _AppEntry: Lỗi fetch role, dùng mặc định "user": $e');
    }

    if (mounted) {
      setState(() {
        _user = freshUser;
        _role = role;
        _authReady = true;
      });
    }
  }

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _splashDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Giai đoạn 1: Splash đang chạy
    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // Giai đoạn 2: Splash xong nhưng auth chưa xong (rất hiếm, vì splash mất 2.5s)
    // Hiển thị nền navy thay vì nền trắng để không bị flash
    if (!_authReady) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: SizedBox.shrink(),
      );
    }

    // Giai đoạn 3: Cả hai xong → chuyển quyền điều khiển cho AuthWrapper
    // Truyền dữ liệu đã pre-fetch để AuthWrapper không phải load lại
    return AuthWrapper(
      initialUser: _user,
      initialRole: _role,
      hasInitialData: true,
    );
  }
}