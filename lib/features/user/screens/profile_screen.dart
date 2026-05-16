import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Hồ Sơ & Cài Đặt'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Avatar
          Center(child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: AppColors.primaryGradient),
                border: Border.all(color: AppColors.accent, width: 3)),
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
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
              ),
            ),
          ])),
          const SizedBox(height: 12),
          Center(child: Text(user?.displayName ?? 'Người dùng', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary))),
          const SizedBox(height: 4),
          Center(child: Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          const SizedBox(height: 28),

          // Name edit
          if (_isEditingName) ...[
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _saving ? null : () => setState(() {
                    _isEditingName = false;
                    _nameCtrl.text = user?.displayName ?? '';
                  }),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _saving ? null : _saveName,
                  child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ] else ...[
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => setState(() => _isEditingName = true),
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
              label: const Text('Điều chỉnh thông tin tài khoản', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ],
          const SizedBox(height: 28),

          // Logout
          _sectionTitle('Tài khoản'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Không push AuthScreen thủ công — AuthWrapper listen authStateChanges()
              // sẽ tự động rebuild về AuthScreen.
              // Chỉ cần pop về root (AuthWrapper).
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            label: const Text('Đăng xuất', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary));

  Widget _avatarPlaceholder(User? user) {
    final name = user?.displayName ?? user?.email ?? '?';
    return Container(color: AppColors.primary, child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))));
  }
}
