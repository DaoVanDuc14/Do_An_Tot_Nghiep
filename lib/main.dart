import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import thêm auth
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_wrapper.dart';

// Xóa import thừa

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      // Sử dụng AuthWrapper nâng cao (từ Do_An_Tot_Nghiep)
      // Hỗ trợ: Google Sign-In, Email Verification, role-based routing
      // Thay thế StreamBuilder inline cũ nhưng giữ nguyên logic phân quyền
      home: const AuthWrapper(),
    );
  }
}