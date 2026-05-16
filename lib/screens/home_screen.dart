import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/topic.dart';
import 'topic_detail_screen.dart';
// --- WIDGET TÍNH % TIẾN ĐỘ (Giữ nguyên) ---
class TopicProgressWidget extends StatelessWidget {
  final String topicId;
  const TopicProgressWidget({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sentences').where('topicId', isEqualTo: topicId).snapshots(),
      builder: (context, sentenceSub) {
        if (!sentenceSub.hasData) return const LinearProgressIndicator(color: Colors.teal);

        int totalSentences = sentenceSub.data!.docs.length;
        if (totalSentences == 0) return const Text("0% hoàn thành", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('user_progress').where('uid', isEqualTo: user?.uid).where('topicId', isEqualTo: topicId).snapshots(),
          builder: (context, progressSub) {
            double average = 0;
            if (progressSub.hasData && progressSub.data!.docs.isNotEmpty) {
              int totalScore = 0;
              for (var doc in progressSub.data!.docs) {
                totalScore += (doc['score'] as int);
              }
              average = totalScore / totalSentences;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: average / 100, backgroundColor: Colors.grey[200], color: const Color(0xFF00B4D8), minHeight: 6),
                ),
                const SizedBox(height: 6),
                Text("${average.toStringAsFixed(0)}% hoàn thành", style: const TextStyle(fontSize: 13, color: Color(0xFF7F8C8D), fontWeight: FontWeight.w600)),
              ],
            );
          },
        );
      },
    );
  }
}

// ĐÃ CHUYỂN THÀNH STATEFUL WIDGET ĐỂ QUẢN LÝ TRẠNG THÁI TÌM KIẾM
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- BIẾN QUẢN LÝ TÌM KIẾM ---
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // HÀM HIỂN THỊ HỘP THOẠI THÊM / SỬA CHỦ ĐỀ
  void _showTopicDialog(BuildContext context, {Topic? topic}) {
    final bool isEdit = topic != null;
    final TextEditingController titleController = TextEditingController(text: isEdit ? topic.title : '');
    final TextEditingController descController = TextEditingController(text: isEdit ? topic.description : '');
    bool isPublic = isEdit ? topic.isPublic : false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(isEdit ? 'Sửa Chủ Đề' : 'Thêm Chủ Đề', style: const TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: InputDecoration(labelText: 'Tên chủ đề', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    TextField(controller: descController, maxLines: 2, decoration: InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(isPublic ? Icons.public : Icons.lock_outline, color: isPublic ? Colors.green : Colors.grey),
                              const SizedBox(width: 8),
                              Text(isPublic ? 'Công khai' : 'Cá nhân', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(value: isPublic, activeColor: Colors.green, onChanged: (val) => setStateDialog(() => isPublic = val)),
                        ],
                      ),
                    )
                  ],
                ),
                actions: [
                  TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (titleController.text.isNotEmpty) {
                        setStateDialog(() => isSaving = true);

                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          try {
                            if (isEdit) {
                              await FirebaseFirestore.instance.collection('topics').doc(topic.id).update({
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'isPublic': isPublic,
                              });
                            } else {
                              String authorName = 'Ẩn danh';
                              final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                              if (userDoc.exists) authorName = userDoc.data()?['name'] ?? 'Ẩn danh';

                              await FirebaseFirestore.instance.collection('topics').add({
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'imageUrl': '',
                                'uid': user.uid,
                                'authorName': authorName,
                                'isPublic': isPublic,
                                'createdAt': Timestamp.now(),
                              });
                            }
                          } catch (e) {
                            print("Lỗi: $e");
                          }
                        }
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  // HÀM XÁC NHẬN VÀ XÓA CHỦ ĐỀ
  void _confirmDeleteTopic(BuildContext context, Topic topic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chủ đề?'),
        content: const Text('Bạn có chắc chắn muốn xóa chủ đề này không? Toàn bộ câu hỏi bên trong cũng sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sentences = await FirebaseFirestore.instance.collection('sentences').where('topicId', isEqualTo: topic.id).get();
              for (var doc in sentences.docs) {
                await doc.reference.delete();
              }
              await FirebaseFirestore.instance.collection('topics').doc(topic.id).delete();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // HÀM DÙNG CHUNG ĐỂ VẼ DANH SÁCH CHỦ ĐỀ CÓ TÍCH HỢP TÌM KIẾM
  Widget _buildTopicList(Stream<QuerySnapshot> stream, {required bool isExploreTab}) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2C3E50)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(isExploreTab ? 'Chưa có chủ đề cộng đồng nào.' : 'Bạn chưa tạo chủ đề nào.', style: const TextStyle(color: Colors.grey, fontSize: 15)));
        }

        // Lấy danh sách thô từ Firebase
        List<Topic> topics = snapshot.data!.docs.map((doc) => Topic.fromFirestore(doc)).toList();

        // LOGIC LỌC TÌM KIẾM (Chạy nội bộ trên App)
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase().trim();
          topics = topics.where((topic) {
            final matchTitle = topic.title.toLowerCase().contains(query);
            final matchAuthor = topic.authorName.toLowerCase().contains(query);
            return matchTitle || matchAuthor;
          }).toList();
        }

        // Nếu tìm không thấy
        if (topics.isEmpty) {
          return const Center(
            child: Text("Không tìm thấy kết quả phù hợp.", style: TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
          physics: const BouncingScrollPhysics(),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            final bool isOwner = topic.uid == currentUser?.uid;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TopicDetailScreen(topic: topic))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          height: 64, width: 64,
                          decoration: BoxDecoration(color: const Color(0xFF2C3E50).withOpacity(0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2C3E50), size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Đánh dấu (Highlight) kết quả tìm kiếm nếu muốn (Ở đây giữ UI chuẩn cho mượt)
                              Text(topic.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                              const SizedBox(height: 4),
                              Text(topic.description, style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)), maxLines: 1, overflow: TextOverflow.ellipsis),

                              if (isExploreTab)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey),
                                      const SizedBox(width: 4),
                                      Text(topic.authorName, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),

                              TopicProgressWidget(topicId: topic.id),
                            ],
                          ),
                        ),

                        if (isOwner)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _showTopicDialog(context, topic: topic);
                              else if (value == 'delete') _confirmDeleteTopic(context, topic);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Sửa')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Xóa', style: TextStyle(color: Colors.red))])),
                            ],
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDC3C7), size: 28),
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2C3E50),
          elevation: 0,
          centerTitle: true,

          // 1. GÓC TRÁI (LEADING): Nút Đăng xuất hoặc Nút Quay lại
          leading: _isSearching
              ? IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C3E50)),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _searchQuery = "";
              });
            },
          )
              : IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
            tooltip: 'Đăng xuất',
          ),

          // 2. CHÍNH GIỮA (TITLE): Thanh tìm kiếm hoặc Tiêu đề App
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Nhập tên chủ đề, tác giả...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 18),
            cursorColor: const Color(0xFF2C3E50),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          )
              : const Text('Học Tiếng Việt AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),

          // 3. GÓC PHẢI (ACTIONS): Nút Tìm kiếm hoặc Nút Xóa chữ
          actions: [
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = ""; // Xóa chữ để hiện lại toàn bộ danh sách
                  });
                },
                tooltip: 'Xóa',
              )
            else
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Color(0xFF2C3E50)),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
                tooltip: 'Tìm kiếm',
              ),
          ],

          bottom: const TabBar(
            indicatorColor: Color(0xFF2C3E50),
            indicatorWeight: 3,
            labelColor: Color(0xFF2C3E50),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: 'Cá nhân'), 
              Tab(text: 'Khám phá'),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showTopicDialog(context),
          backgroundColor: const Color(0xFF2C3E50),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Chủ đề', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),

        body: TabBarView(
          children: [
            _buildTopicList(FirebaseFirestore.instance.collection('topics').where('uid', isEqualTo: currentUser?.uid).snapshots(), isExploreTab: false),
            _buildTopicList(FirebaseFirestore.instance.collection('topics').where('isPublic', isEqualTo: true).snapshots(), isExploreTab: true),
          ],
        ),
      ),
    );
  }
}