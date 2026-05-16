import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firestore_service.dart';

class AdminExamResultsScreen extends StatelessWidget {
  final String examPaperId;
  final String examTitle;

  const AdminExamResultsScreen({
    super.key,
    required this.examPaperId,
    required this.examTitle,
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kết quả thi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            Text(examTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ]
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.examLeaderboardStream(examPaperId, limit: 100),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có ai hoàn thành bài thi này.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ]
              )
            );
          }

          // Lọc danh sách unique user, giữ lại lần thi điểm cao nhất
          final Map<String, DocumentSnapshot> uniqueUsers = {};
          for (var doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final userId = data['userId'] as String? ?? '';
            if (userId.isEmpty) continue;
            
            final currentScore = data['score'] as int? ?? 0;
            
            if (uniqueUsers.containsKey(userId)) {
              final existingScore = (uniqueUsers[userId]!.data() as Map<String, dynamic>)['score'] as int? ?? 0;
              if (currentScore > existingScore) {
                uniqueUsers[userId] = doc;
              }
            } else {
              uniqueUsers[userId] = doc;
            }
          }
          
          final results = uniqueUsers.values.toList();
          results.sort((a, b) {
            final sA = (a.data() as Map<String, dynamic>)['score'] as int? ?? 0;
            final sB = (b.data() as Map<String, dynamic>)['score'] as int? ?? 0;
            return sB.compareTo(sA);
          });

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                width: double.infinity,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Text('Có ${results.length} người dùng đã làm bài thi này', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final data = results[index].data() as Map<String, dynamic>;
                    final userId = data['userId'] as String? ?? '';
                    final score = data['score'] as int? ?? 0;
                    final timeTaken = data['timeTaken_seconds'] as int? ?? data['timeFinished'] as int? ?? data['durationSeconds'] as int? ?? 0;
                    final completedAt = data['completedAt'] as Timestamp?;
                    
                    final timeStr = completedAt != null 
                        ? '${completedAt.toDate().day}/${completedAt.toDate().month} ${completedAt.toDate().hour}:${completedAt.toDate().minute.toString().padLeft(2, '0')}'
                        : 'Không rõ';

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: FirestoreService.getUserData(userId),
                      builder: (context, userSnap) {
                        final userData = userSnap.data;
                        final userName = userData?['name'] ?? 'Người dùng (đã xóa)';
                        final userEmail = userData?['email'] ?? 'Không có email';
                        
                        final int m = timeTaken ~/ 60;
                        final int s = timeTaken % 60;
                        final String durStr = m > 0 ? '$m phút $s giây' : '$s giây';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade400 : (index == 2 ? Colors.brown.shade300 : AppColors.primary.withValues(alpha: 0.1))),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: index < 3 ? Colors.white : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(userEmail, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(durStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$score', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent)),
                              const Text('điểm', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
