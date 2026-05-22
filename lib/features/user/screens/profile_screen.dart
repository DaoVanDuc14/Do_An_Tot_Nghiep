import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
                        'Hồ Sơ & Cài Đặt',
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(children: [
                        // Avatar
                        Stack(alignment: Alignment.bottomRight, children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: AppColors.primaryGradient),
                              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _uploadingAvatar
                                ? const CircularProgressIndicator(color: Colors.white)
                                : ClipOval(child: photoUrl != null
                                    ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarPlaceholder(user))
                                    : _avatarPlaceholder(user)),
                          ),
                          GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: AppColors.accentGradient),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Text(user?.displayName ?? 'Người dùng', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ]),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),

                    const SizedBox(height: 20),

                    // ── Edit Name Section ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sectionTitle('Thông tin tài khoản'),
                        const SizedBox(height: 16),

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
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                onPressed: _saving ? null : () => setState(() {
                                  _isEditingName = false;
                                  _nameCtrl.text = user?.displayName ?? '';
                                }),
                                child: const Text('Hủy'),
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
                                  child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ]),
                        ] else ...[
                          SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: () => setState(() => _isEditingName = true),
                            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                            label: const Text('Điều chỉnh thông tin tài khoản', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )),
                        ],
                      ]),
                    ).animate().fadeIn(duration: 500.ms, delay: 150.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 150.ms),

                    const SizedBox(height: 20),

                    // ── Logout ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sectionTitle('Tài khoản'),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!mounted) return;
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          icon: Icon(Icons.logout_rounded, color: AppColors.error),
                          label: Text('Đăng xuất', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 300.ms),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary));

  Widget _avatarPlaceholder(User? user) {
    final name = user?.displayName ?? user?.email ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(color: AppColors.primary, child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))));
  }
}
