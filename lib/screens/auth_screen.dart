import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;

  bool _isLogin = true; // Trạng thái: true = Đăng nhập, false = Đăng ký
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // XỬ LÝ ĐĂNG NHẬP
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        // XỬ LÝ ĐĂNG KÝ
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Tạo một hồ sơ người dùng trên Firestore để sau này lưu điểm
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'email': email,
          'createdAt': Timestamp.now(),
          'totalScore': 0, // Điểm số ban đầu
        });
      }
      // Đăng nhập/Đăng ký thành công thì StreamBuilder ở main.dart sẽ tự động chuyển trang!
    } on FirebaseAuthException catch (e) {
      String message = 'Đã xảy ra lỗi, vui lòng thử lại!';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email hoặc mật khẩu không chính xác!';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email này đã được đăng ký!';
      } else if (e.code == 'weak-password') {
        message = 'Mật khẩu phải có ít nhất 6 ký tự!';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo hoặc Tiêu đề
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded, size: 64, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'Chào mừng trở lại!' : 'Tạo tài khoản mới',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 32),

                // Form nhập liệu
                if (!_isLogin) ...[
                  _buildTextField(controller: _nameController, icon: Icons.person_outline, label: 'Họ và Tên'),
                  const SizedBox(height: 16),
                ],
                _buildTextField(controller: _emailController, icon: Icons.email_outlined, label: 'Email', isEmail: true),
                const SizedBox(height: 16),
                _buildTextField(controller: _passwordController, icon: Icons.lock_outline, label: 'Mật khẩu', isPassword: true),
                const SizedBox(height: 32),

                // Nút Xác nhận
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _submitAuth,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                        _isLogin ? 'Đăng Nhập' : 'Đăng Ký',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nút chuyển đổi Đăng nhập / Đăng ký
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Chưa có tài khoản? Đăng ký ngay' : 'Đã có tài khoản? Đăng nhập',
                    style: const TextStyle(color: Color(0xFF7F8C8D), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hàm tạo TextField dùng chung cho gọn code
  Widget _buildTextField({required TextEditingController controller, required IconData icon, required String label, bool isPassword = false, bool isEmail = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF7F8C8D)),
        filled: true,
        fillColor: const Color(0xFFF4F7F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 1.5)),
      ),
    );
  }
}