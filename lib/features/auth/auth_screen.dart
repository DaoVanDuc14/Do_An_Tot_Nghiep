import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/firestore_service.dart';

// ignore_for_file: use_build_context_synchronously

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

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

  // ─── ĐĂNG NHẬP / ĐĂNG KÝ ──────────────────────────────────
  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      _showSnack(AppStrings.fillAllFields, Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // ── ĐĂNG NHẬP ─────────────────────
        // signIn thành công → authStateChanges() trong AuthWrapper
        // tự động rebuild → chuyển màn Home/Admin
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        // Nếu đến đây không throw → login OK, AuthWrapper sẽ tự xử lý
      } else {
        // ── ĐĂNG KÝ (Direct) ──
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        await FirestoreService.createUserProfile(cred.user!, name);
        await cred.user?.sendEmailVerification();
        if (mounted) {
          _showSnack('🎉 Đăng ký thành công! Vui lòng kiểm tra email để xác minh.', Colors.green);
        }
        // AuthWrapper sẽ tự xử lý việc chuyển màn sang VerifyEmailScreen
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnack(_mapAuthError(e), Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Lỗi: $e', Colors.red);
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Map Firebase Auth error codes → thông báo tiếng Việt
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Mật khẩu không chính xác.';
      case 'invalid-credential':
        return AppStrings.wrongCredentials;
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';
      case 'email-already-in-use':
        return AppStrings.emailInUse;
      case 'weak-password':
        return AppStrings.weakPassword;
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng đợi một lát rồi thử lại.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      default:
        return e.message ?? AppStrings.errorGeneric;
    }
  }

  // ─── GOOGLE SIGN-IN ────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        final result = await _auth.signInWithPopup(provider);
        final fbUser = result.user;
        if (fbUser != null) {
          await FirestoreService.createUserProfileIfNotExists(fbUser);
        }
      } else {
        final googleUser = await GoogleSignIn(
          serverClientId: '291922863219-9k9rulfaildrk17fkfr26ii9p5rhd87h.apps.googleusercontent.com',
        ).signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        final result = await _auth.signInWithCredential(credential);
        final fbUser = result.user;
        if (fbUser != null) {
          await FirestoreService.createUserProfileIfNotExists(fbUser);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnack('Lỗi Firebase: ${e.message}', Colors.red);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnack('Đăng nhập Google bị hủy: ${e.message}', Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Lỗi đăng nhập Google: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  // ─── SNACKBAR ──────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── QUÊN MẬT KHẨU ────────────────────────────────────────
  void _showForgotPassword() {
    final emailCtrl = TextEditingController();
    bool sending = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quên mật khẩu', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Nhập email tài khoản của bạn.\nChúng tôi sẽ gửi email đặt lại mật khẩu.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: sending ? null : () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) {
                _showSnack('Vui lòng nhập email.', Colors.orange);
                return;
              }
              setD(() => sending = true);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _showSnack('📧 Đã gửi email đặt lại mật khẩu!\nVui lòng kiểm tra hộp thư (kể cả Spam).', Colors.green);
              } on FirebaseAuthException catch (e) {
                if (ctx.mounted) {
                  setD(() => sending = false);
                }
                _showSnack(_mapAuthError(e), Colors.red);
              } catch (e) {
                if (ctx.mounted) {
                  setD(() => sending = false);
                }
                _showSnack('Lỗi: $e', Colors.red);
              }
            },
            child: sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Gửi email', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? AppStrings.welcomeBack : AppStrings.createAccount,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Đăng nhập để tiếp tục học' : 'Tạo tài khoản để bắt đầu',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),

                if (!_isLogin) ...[
                  _buildTextField(
                      controller: _nameController,
                      icon: Icons.person_outline,
                      label: AppStrings.nameLabel),
                  const SizedBox(height: 14),
                ],
                _buildTextField(
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    label: AppStrings.emailLabel,
                    isEmail: true),
                const SizedBox(height: 14),
                _buildTextField(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    label: AppStrings.passwordLabel,
                    isPassword: true),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _submitAuth,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            _isLogin ? AppStrings.login : AppStrings.register,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  const Expanded(child: Divider(color: Color(0xFFDEE2E6))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('hoặc', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFDEE2E6))),
                ]),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDEE2E6), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                    child: _isGoogleLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: const Text('G',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4285F4))),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Đăng nhập với Google',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPassword,
                      child: const Text('Quên mật khẩu?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Chưa có tài khoản? Đăng ký ngay' : 'Đã có tài khoản? Đăng nhập',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool isPassword = false,
    bool isEmail = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }
}