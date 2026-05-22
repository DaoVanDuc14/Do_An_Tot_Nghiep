import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  String _formatTime(int s) => '${s ~/ 60}p${s % 60}s';

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

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
                        '🏆 Bảng Xếp Hạng',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Body ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.leaderboardStream(limit: 100),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.leaderboard_outlined, size: 64, color: Colors.white38),
                        const SizedBox(height: 16),
                        Text('Chưa có kết quả nào.\nHãy là người đầu tiên!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16)),
                      ]));
                    }

                    final sorted = snap.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['docId'] = doc.id;
                      return data;
                    }).toList();

                    return Column(children: [
                      // Top 3 podium
                      if (sorted.length >= 3)
                        _buildPodium(sorted).animate().fadeIn(duration: 600.ms).slideY(begin: -0.05, end: 0, duration: 600.ms),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                  color: isMe ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isMe ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent, width: 1.5),
                                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    // Rank
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        gradient: i < 3 ? LinearGradient(
                                          colors: [
                                            [const Color(0xFFFFD54F), const Color(0xFFFFA000)],
                                            [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)],
                                            [const Color(0xFFD7A86E), const Color(0xFFCD7F32)],
                                          ][i],
                                        ) : null,
                                        color: i >= 3 ? AppColors.background : null,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(child: i < 3
                                          ? Text(['🥇','🥈','🥉'][i], style: const TextStyle(fontSize: 18))
                                          : Text('${i+1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13))),
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
                                        Flexible(child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isMe ? AppColors.primary : AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                                        if (isMe) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(6)), child: const Text('Bạn', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))],
                                      ]),
                                    ])),
                                    Text('${score.toInt()}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: i < 3 ? [const Color(0xFFF57C00), const Color(0xFF757575), const Color(0xFFCD7F32)][i] : AppColors.primary)),
                                    const Text(' đ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ]),
                                ),
                              ).animate().fadeIn(duration: 350.ms, delay: (50 * i).ms).slideX(begin: 0.03, end: 0, duration: 300.ms, delay: (50 * i).ms);
                            },
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> sorted) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
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
      Text(medal, style: TextStyle(fontSize: height == 90 ? 36 : 28)),
      const SizedBox(height: 6),
      Text(shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 2),
      Text('${score.toInt()} đ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
    ]);
  }
}
