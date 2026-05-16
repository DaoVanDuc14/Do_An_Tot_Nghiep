import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/topic.dart';
import '../../../data/models/exam_paper.dart';
import '../../../services/firestore_service.dart';
import 'topic_detail_screen.dart';
import 'new_exam_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'user_exam_management.dart';

// ─── Progress Widget ───────────────────────────────────────────
class TopicProgressWidget extends StatelessWidget {
  final String topicId;
  const TopicProgressWidget({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.sentencesStream(topicId),
      builder: (context, sSnap) {
        if (!sSnap.hasData) return const LinearProgressIndicator(color: AppColors.accent);
        final total = sSnap.data!.docs.length;
        if (total == 0) return const Text('0% hoàn thành', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold));
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.topicProgressStream(uid, topicId),
          builder: (context, pSnap) {
            double avg = 0;
            if (pSnap.hasData && pSnap.data!.docs.isNotEmpty) {
              int sum = 0;
              for (var d in pSnap.data!.docs) {
                sum += (d['score'] as num).toInt();
              }
              avg = sum / total;
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: avg / 100, backgroundColor: Colors.grey[200], color: AppColors.accent, minHeight: 6)),
              const SizedBox(height: 6),
              Text('${avg.toStringAsFixed(0)}% hoàn thành', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ]);
          },
        );
      },
    );
  }
}

// ─── HomeScreen ────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {}); // Rebuild to update FAB visibility
    });
  }

  @override
  void dispose() { 
    _searchCtrl.dispose(); 
    _tabController.dispose();
    super.dispose(); 
  }

  void _showTopicDialog(BuildContext context, {Topic? topic}) {
    final isEdit = topic != null;
    final titleCtrl = TextEditingController(text: isEdit ? topic.title : '');
    final descCtrl = TextEditingController(text: isEdit ? topic.description : '');
    bool isPublic = isEdit ? topic.isPublic : false;
    bool saving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Sửa Chủ Đề' : 'Thêm Chủ Đề', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Tên chủ đề', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 14),
          TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [Icon(isPublic ? Icons.public : Icons.lock_outline, color: isPublic ? Colors.green : Colors.grey), const SizedBox(width: 8), Text(isPublic ? 'Công khai' : 'Cá nhân', style: const TextStyle(fontWeight: FontWeight.bold))]),
              Switch(value: isPublic, activeColor: Colors.green, onChanged: (v) => setD(() => isPublic = v)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: saving ? null : () async {
              if (titleCtrl.text.isEmpty) return;
              setD(() => saving = true);
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  if (isEdit) {
                    await FirestoreService.updateTopic(topic.id, {'title': titleCtrl.text.trim(), 'description': descCtrl.text.trim(), 'isPublic': isPublic});
                  } else {
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                    final rawData = userDoc.data();
                    final authorName = rawData?['name'] ?? 'Ẩn danh';
                    await FirestoreService.createTopic({'title': titleCtrl.text.trim(), 'description': descCtrl.text.trim(), 'imageUrl': '', 'uid': user.uid, 'authorName': authorName, 'isPublic': isPublic});
                  }
                } catch (e) { debugPrint('Lỗi: $e'); }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  void _confirmDeleteTopic(BuildContext context, Topic topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa chủ đề?'),
        content: const Text('Toàn bộ câu hỏi bên trong cũng sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () async { Navigator.pop(ctx); await FirestoreService.deleteTopic(topic.id); }, child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTopicList(Stream<QuerySnapshot> stream, {required bool isExplore}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Text(isExplore ? 'Chưa có chủ đề cộng đồng nào.' : 'Bạn chưa tạo chủ đề nào.', style: const TextStyle(color: Colors.grey, fontSize: 15)));
        var topics = FirestoreService.parseTopics(snap.data!);
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          topics = topics.where((t) => t.title.toLowerCase().contains(q) || t.authorName.toLowerCase().contains(q)).toList();
        }
        if (topics.isEmpty) return const Center(child: Text('Không tìm thấy kết quả phù hợp.', style: TextStyle(color: Colors.grey, fontSize: 16)));
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
          physics: const BouncingScrollPhysics(),
          itemCount: topics.length,
          itemBuilder: (context, i) {
            final t = topics[i];
            final isOwner = t.uid == uid;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Material(color: Colors.transparent, child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: t))),
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  Container(height: 64, width: 64, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 30)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(t.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (isExplore) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey), const SizedBox(width: 4), Text(t.authorName, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic))])),
                    TopicProgressWidget(topicId: t.id),
                  ])),
                  if (isOwner) PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') { _showTopicDialog(context, topic: t); }
                      else if (v == 'delete') { _confirmDeleteTopic(context, t); }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Sửa')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Xóa', style: TextStyle(color: Colors.red))])),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                  ) else const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 28),
                ])),
              )),
            );
          },
        );
      },
    );
  }

  Widget _buildOnlineTestTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.examPapersStream(),
      builder: (context, snap) {
        bool isLoading = snap.connectionState == ConnectionState.waiting;
        List<ExamPaper> papers = [];
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final allPapers = FirestoreService.parseExamPapers(snap.data!);
          papers = allPapers.where((p) => p.isPublished).toList();
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
          children: [
            // Section 1: Header - Bảng xếp hạng & Bài thi của tôi (hoặc chia thành card riêng)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber, width: 1.5),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.leaderboard_rounded, size: 36, color: Colors.amber),
                          SizedBox(height: 8),
                          Text('Bảng xếp hạng', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserExamManagement())),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 36, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text('Bài thi của tôi', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 2: Hệ thống đề thi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                const Icon(Icons.assignment_rounded, color: Colors.white70, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hệ thống Đề Thi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(isLoading ? 'Đang tải...' : '${papers.length} đề thi đang mở', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),

            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (papers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Chưa có đề thi nào.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Admin chưa tạo đề thi nào hoặc chưa xuất bản.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ),
              )
            else ...[
              const Text('Chọn đề thi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              ...papers.map((paper) => _buildPaperCard(context, paper)),
            ]
          ],
        );
      },
    );
  }

  void _sharePaper(BuildContext context, ExamPaper paper) {
    // Deep link format: vkulearning://exam?id=<examId>
    // Hoặc web URL: https://vku-vietnamese-learning.web.app/?examId=<examId>
    final link = 'https://vku-vietnamese-learning.web.app/?examId=${paper.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🔗 Đã sao chép link: ${paper.title}'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
    ));
  }

  Widget _buildPaperCard(BuildContext context, ExamPaper paper) {
    bool _loading = false;
    return StatefulBuilder(
      builder: (context, setS) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(paper.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${paper.durationMinutes} phút', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  if (paper.creatorName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Flexible(child: Text(paper.creatorName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ])),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.accent),
                tooltip: 'Chia sẻ link bài thi',
                onPressed: () => _sharePaper(context, paper),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _loading ? null : () async {
                  setS(() => _loading = true);
                  try {
                    final snap = await FirestoreService.examQuestionsStream(paper.id).first;
                    final questions = FirestoreService.parseExamQuestions(snap);
                    if (!context.mounted) return;
                    if (questions.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Đề thi chưa có câu hỏi!'), backgroundColor: Colors.orange));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => NewExamScreen(paper: paper, questions: questions)));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Lỗi tải đề: $e'), backgroundColor: Colors.red));
                  } finally {
                    if (context.mounted) setS(() => _loading = false);
                  }
                },
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: Text(_loading ? 'Đang tải...' : 'Bắt đầu thi',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
        leading: _isSearching
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() { _isSearching = false; _searchCtrl.clear(); _searchQuery = ''; }))
            : IconButton(icon: const Icon(Icons.account_circle_outlined, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())), tooltip: 'Hồ sơ'),
        title: _isSearching
            ? TextField(controller: _searchCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Nhập tên chủ đề, tác giả...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: AppColors.primary, fontSize: 18), cursorColor: AppColors.primary, onChanged: (v) => setState(() => _searchQuery = v))
            : const Text('Học Tiếng Việt AI'),
        actions: [
          _isSearching
              ? IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }))
              : IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => setState(() => _isSearching = true)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [Tab(text: 'Cá nhân'), Tab(text: 'Khám phá'), Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Đề Thi')],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showTopicDialog(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Chủ đề', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTopicList(FirestoreService.myTopicsStream(uid ?? ''), isExplore: false),
          _buildTopicList(FirestoreService.publicTopicsStream(), isExplore: true),
          _buildOnlineTestTab(),
        ],
      ),
    );
  }

}
