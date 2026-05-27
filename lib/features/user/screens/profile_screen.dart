import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await user.updateDisplayName(_nameCtrl.text.trim());
      await FirestoreService.updateUserProfile(user.uid, {'name': _nameCtrl.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã cập nhật tên!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() {
        _saving = false;
        _isEditingName = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        url = await StorageService.uploadImage(bytes: bytes, fileName: picked.name, folder: 'avatars');
      } else {
        url = await StorageService.uploadImage(filePath: picked.path, folder: 'avatars');
      }
      await user.updatePhotoURL(url);
      await FirestoreService.updateUserProfile(user.uid, {'photoUrl': url});
      if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã cập nhật ảnh đại diện!'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi upload: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              // Xóa phiên Google để lần sau cho chọn tài khoản khác
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              AppColors.background,
            ],
            stops: [0.0, 0.25, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Hồ Sơ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // balance
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // ── Avatar Card ──
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(children: [
                        // Avatar
                        Stack(alignment: Alignment.bottomRight, children: [
                          Container(
                            width: 110, height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: AppColors.primaryGradient),
                              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _uploadingAvatar
                                ? const CircularProgressIndicator(color: Colors.white)
                                : ClipOval(child: photoUrl != null
                                    ? Image.network(photoUrl, fit: BoxFit.cover, width: 110, height: 110, errorBuilder: (_, __, ___) => _avatarPlaceholder(user))
                                    : _avatarPlaceholder(user)),
                          ),
                          GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: AppColors.accentGradient),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 17),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        Text(
                          user?.displayName ?? 'Người dùng',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.email ?? '',
                            style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),

                    const SizedBox(height: 24),

                    // ── Action Buttons Card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(children: [
                        // ── Editing Name Form ──
                        if (_isEditingName) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Tên hiển thị',
                              prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              filled: true, fillColor: AppColors.background,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                                ),
                                onPressed: _saving ? null : () => setState(() {
                                  _isEditingName = false;
                                  _nameCtrl.text = user?.displayName ?? '';
                                }),
                                child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _saving ? null : _saveName,
                                  child: _saving
                                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                        ],

                        // ── Button: Điều chỉnh thông tin ──
                        if (!_isEditingName)
                          _buildActionButton(
                            icon: Icons.edit_rounded,
                            label: 'Điều chỉnh thông tin',
                            iconColor: Colors.white,
                            gradient: AppColors.primaryGradient,
                            onTap: () => setState(() => _isEditingName = true),
                          ),

                        if (!_isEditingName) const SizedBox(height: 12),

                        // ── Button: Đăng xuất ──
                        _buildActionButton(
                          icon: Icons.logout_rounded,
                          label: 'Đăng xuất',
                          iconColor: Colors.white,
                          gradient: const [Color(0xFFD32F2F), Color(0xFFEF5350)],
                          onTap: _confirmLogout,
                        ),
                      ]),
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 200.ms),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút action đẹp với gradient, icon và label
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(User? user) {
    final name = user?.displayName ?? user?.email ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(color: AppColors.primary, child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))));
  }
}
