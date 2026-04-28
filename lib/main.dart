import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import thêm auth
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart'; // Import màn hình Auth mới tạo

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C3E50)),
        useMaterial3: true,
      ),
      // THIẾT LẬP NGƯỜI GÁC CỔNG Ở ĐÂY
      home: StreamBuilder<User?>(
        // Lắng nghe liên tục trạng thái đăng nhập của Firebase
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Đang chờ kiểm tra
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Nếu có dữ liệu user -> Đã đăng nhập -> Vào thẳng Trang chủ
          if (snapshot.hasData) {
            return const HomeScreen();
          }

          // Nếu không -> Ra màn hình Đăng nhập
          return const AuthScreen();
        },
      ),
    );
  }
}