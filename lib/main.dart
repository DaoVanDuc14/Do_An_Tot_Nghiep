import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Entry point: hiển thị Splash Screen ≥ 2.5s rồi mới vào AuthWrapper
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _splashDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const AuthWrapper();
  }
}