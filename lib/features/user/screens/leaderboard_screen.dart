import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  String _formatTime(int s) => '${s ~/ 60}p${s % 60}s';

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🏆 Bảng Xếp Hạng'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.leaderboardStream(limit: 100),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.leaderboard_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Chưa có kết quả nào.\nHãy là người đầu tiên!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            ]));
          }

          final sorted = snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['docId'] = doc.id;
            return data;
          }).toList();

          return Column(children: [
            // Top 3 podium
            if (sorted.length >= 3) _buildPodium(sorted),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final d = sorted[i];
                  final uid = d['uid'] as String? ?? d['docId'] as String? ?? '';
                  final name = d['name'] as String? ?? 'Ẩn danh';
                  final score = d['totalScore'] as num? ?? 0;
                  final avatarUrl = d['photoUrl'] as String? ?? d['avatarUrl'] as String? ?? '';
                  final isMe = uid == myUid;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isMe ? AppColors.primary : Colors.transparent, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        // Rank
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: i == 0 ? const Color(0xFFFFD700) : (i == 1 ? const Color(0xFFC0C0C0) : (i == 2 ? const Color(0xFFCD7F32) : Colors.grey.shade100)),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: i < 3
                              ? Text(['🥇','🥈','🥉'][i], style: const TextStyle(fontSize: 18))
                              : Text('${i+1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                        ),
                        const SizedBox(width: 12),
                        // Avatar
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: AppColors.primaryGradient),
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: avatarUrl.isNotEmpty 
                              ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
                              : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMe ? AppColors.primary : AppColors.textPrimary)),
                            if (isMe) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)), child: const Text('Bạn', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))],
                          ]),
                        ])),
                        Text('${score.toInt()}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: i < 3 ? [const Color(0xFFFFD700), const Color(0xFF9E9E9E), const Color(0xFFCD7F32)][i] : AppColors.primary)),
                        const Text(' đ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> sorted) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
        _podiumItem(sorted[1], '🥈', 70),
        _podiumItem(sorted[0], '🥇', 90),
        _podiumItem(sorted[2], '🥉', 70),
      ]),
    );
  }

  Widget _podiumItem(Map<String, dynamic> d, String medal, double height) {
    final name = (d['name'] as String? ?? 'Ẩn danh');
    final score = d['totalScore'] as num? ?? 0;
    final shortName = name.length > 8 ? '${name.substring(0, 8)}...' : name;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(medal, style: TextStyle(fontSize: height == 90 ? 32 : 24)),
      const SizedBox(height: 4),
      Text(shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      Text('${score.toInt()} đ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}
