import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/topic.dart';
import '../models/sentence.dart';
import 'practice_screen.dart';

class TopicDetailScreen extends StatelessWidget {
  final Topic topic;

  const TopicDetailScreen({super.key, required this.topic});

  Color _getScoreColor(int score) {
    if (score == 0) return Colors.grey;
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  // HÀM HIỂN THỊ HỘP THOẠI THÊM / SỬA CÂU NÓI
  void _showSentenceDialog(BuildContext context, {Sentence? sentence}) {
    final bool isEdit = sentence != null;
    final TextEditingController textController = TextEditingController(text: isEdit ? sentence.text : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Sửa Câu Nói' : 'Thêm Câu Nói', style: const TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: textController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Nhập câu tiếng Việt',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (textController.text.isNotEmpty) {
                  if (isEdit) {
                    // CHẾ ĐỘ SỬA
                    await FirebaseFirestore.instance.collection('sentences').doc(sentence.id).update({
                      'text': textController.text.trim(),
                    });
                  } else {
                    // CHẾ ĐỘ THÊM MỚI
                    await FirebaseFirestore.instance.collection('sentences').add({
                      'text': textController.text.trim(),
                      'topicId': topic.id,
                      'audioUrl': '',
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // HÀM XÓA CÂU NÓI
  void _confirmDeleteSentence(BuildContext context, Sentence sentence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa câu này?'),
        content: const Text('Bạn có chắc chắn muốn xóa câu nói này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('sentences').doc(sentence.id).delete();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // BƯỚC QUAN TRỌNG: Kiểm tra xem User hiện tại có phải là Tác giả của Topic này không?
    final bool isOwner = user?.uid == topic.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: true,
        title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey[200], height: 1.0)),
      ),

      // CHỈ HIỂN THỊ NÚT THÊM NẾU LÀ CHỦ NHÂN
      floatingActionButton: isOwner
          ? FloatingActionButton(
        onPressed: () => _showSentenceDialog(context),
        backgroundColor: const Color(0xFF2C3E50),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null, // Nếu không phải chủ, nút + sẽ hoàn toàn biến mất

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sentences').where('topicId', isEqualTo: topic.id).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text(
                    isOwner ? 'Chưa có câu hỏi nào.\nHãy bấm nút + để thêm nhé!' : 'Tác giả chưa cập nhật câu hỏi cho chủ đề này.',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)
                )
            );
          }

          List<Sentence> sentences = snapshot.data!.docs.map((doc) => Sentence.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
            physics: const BouncingScrollPhysics(),
            itemCount: sentences.length,
            itemBuilder: (context, index) {
              final sentence = sentences[index];

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('user_progress').doc("${user?.uid}_${sentence.id}").snapshots(),
                builder: (context, progressSnapshot) {
                  int actualScore = 0;
                  if (progressSnapshot.hasData && progressSnapshot.data!.exists) {
                    actualScore = progressSnapshot.data!['score'] ?? 0;
                  }

                  final scoreColor = _getScoreColor(actualScore);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Bất kể chủ hay khách đều được vào Luyện tập
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PracticeScreen(sentence: sentence)));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                height: 44, width: 44,
                                decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(Icons.play_arrow_rounded, color: scoreColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(sentence.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
                              ),

                              // HIỂN THỊ MENU SỬA XÓA (NẾU LÀ CHỦ), NẾU KHÔNG THÌ HIỆN VÒNG TRÒN ĐIỂM
                              if (isOwner)
                                Row(
                                  children: [
                                    _buildScoreCircle(actualScore, scoreColor),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showSentenceDialog(context, sentence: sentence);
                                        } else if (value == 'delete') {
                                          _confirmDeleteSentence(context, sentence);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Sửa câu này')),
                                        const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
                                      ],
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    )
                                  ],
                                )
                              else
                                _buildScoreCircle(actualScore, scoreColor), // Khách chỉ thấy điểm của họ
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScoreCircle(int score, Color color) {
    return SizedBox(
      width: 48, height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(value: score / 100, backgroundColor: Colors.grey[100], color: color, strokeWidth: 4, strokeCap: StrokeCap.round),
          Center(child: Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))),
        ],
      ),
    );
  }
}