import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/quiz.dart';

class AdminQuizManagement extends StatefulWidget {
  const AdminQuizManagement({super.key});

  @override
  State<AdminQuizManagement> createState() => _AdminQuizManagementState();
}

class _AdminQuizManagementState extends State<AdminQuizManagement> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ============================================================
  //  SHOW CREATE / EDIT DIALOG
  // ============================================================
  void _showQuizDialog(BuildContext context, {Quiz? quiz}) {
    final isEdit = quiz != null;
    final titleController =
        TextEditingController(text: isEdit ? quiz.title : '');
    final targetTextController =
        TextEditingController(text: isEdit ? quiz.targetText : '');

    // Options controllers (MCQ)
    final List<TextEditingController> optionControllers = isEdit
        ? quiz.options.map((o) => TextEditingController(text: o)).toList()
        : List.generate(4, (_) => TextEditingController());

    QuizType selectedType =
        isEdit ? quiz.type : QuizType.pronunciation;
    String audioUrl = isEdit ? quiz.audioUrl : '';
    String? selectedFilePath;
    bool isUploading = false;
    bool isSaving = false;
    String topicId = isEdit ? quiz.topicId : '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          Future<void> pickAudio() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
              allowMultiple: false,
            );
            if (result != null && result.files.single.path != null) {
              setStateDialog(() {
                selectedFilePath = result.files.single.path!;
              });
            }
          }

          Future<String?> uploadAudio(String filePath) async {
            try {
              setStateDialog(() => isUploading = true);
              final fileName =
                  'quizzes/${DateTime.now().millisecondsSinceEpoch}_${filePath.split(Platform.pathSeparator).last}';
              final ref =
                  FirebaseStorage.instance.ref().child(fileName);
              final task = await ref.putFile(File(filePath));
              final url = await task.ref.getDownloadURL();
              return url;
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Lỗi upload: $e')));
              }
              return null;
            } finally {
              setStateDialog(() => isUploading = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEdit ? 'Sửa Quiz' : 'Tạo Quiz mới',
              style: const TextStyle(
                  color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề quiz',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // TARGET TEXT
                  TextField(
                    controller: targetTextController,
                    decoration: InputDecoration(
                      labelText: 'Đáp án đúng (targetText)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // TOPIC ID
                  TextField(
                    onChanged: (v) => topicId = v.trim(),
                    controller:
                        TextEditingController(text: topicId),
                    decoration: InputDecoration(
                      labelText: 'Topic ID (tùy chọn)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // TYPE SELECTOR
                  const Text('Loại quiz:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setStateDialog(
                              () => selectedType = QuizType.pronunciation),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType ==
                                      QuizType.pronunciation
                                  ? const Color(0xFF2C3E50)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '🎙 Phát âm',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      selectedType == QuizType.pronunciation
                                          ? Colors.white
                                          : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setStateDialog(
                              () => selectedType = QuizType.listeningMcq),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType ==
                                      QuizType.listeningMcq
                                  ? const Color(0xFF00B4D8)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '🎧 Nghe-MCQ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      selectedType == QuizType.listeningMcq
                                          ? Colors.white
                                          : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // MCQ OPTIONS
                  if (selectedType == QuizType.listeningMcq) ...[
                    const Text('4 lựa chọn (MCQ):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50))),
                    const SizedBox(height: 8),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: optionControllers[i],
                          decoration: InputDecoration(
                            labelText: 'Lựa chọn ${i + 1}',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // AUDIO UPLOAD
                  const Text('File âm thanh:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50))),
                  const SizedBox(height: 8),
                  if (audioUrl.isNotEmpty && selectedFilePath == null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          const Expanded(
                              child: Text('Đã có audio',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green))),
                          GestureDetector(
                            onTap: () async {
                              await _audioPlayer
                                  .play(UrlSource(audioUrl));
                            },
                            child: const Icon(Icons.play_circle_outline,
                                color: Colors.green),
                          )
                        ],
                      ),
                    ),
                  if (selectedFilePath != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.audio_file_rounded,
                              color: Color(0xFF00B4D8), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedFilePath!
                                  .split(Platform.pathSeparator)
                                  .last,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF00B4D8)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(selectedFilePath == null
                                ? 'Chọn file âm thanh'
                                : 'Đổi file âm thanh'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2C3E50),
                              side: const BorderSide(
                                  color: Color(0xFF2C3E50)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: pickAudio,
                          ),
                        ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving || isUploading
                    ? null
                    : () => Navigator.pop(ctx),
                child:
                    const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving || isUploading
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty ||
                            targetTextController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Vui lòng điền tiêu đề và đáp án!')));
                          return;
                        }

                        setStateDialog(() => isSaving = true);

                        // Upload nếu có file mới
                        if (selectedFilePath != null) {
                          final uploadedUrl =
                              await uploadAudio(selectedFilePath!);
                          if (uploadedUrl != null) {
                            audioUrl = uploadedUrl;
                          } else {
                            setStateDialog(() => isSaving = false);
                            return;
                          }
                        }

                        final List<String> opts =
                            selectedType == QuizType.listeningMcq
                                ? optionControllers
                                    .map((c) => c.text.trim())
                                    .where((t) => t.isNotEmpty)
                                    .toList()
                                : [];

                        final quizData = {
                          'topicId': topicId,
                          'title': titleController.text.trim(),
                          'type': selectedType == QuizType.pronunciation
                              ? 'pronunciation'
                              : 'listening_mcq',
                          'audioUrl': audioUrl,
                          'targetText':
                              targetTextController.text.trim(),
                          'options': opts,
                          'createdAt': Timestamp.now(),
                        };

                        try {
                          if (isEdit) {
                            await FirebaseFirestore.instance
                                .collection('quizzes')
                                .doc(quiz.id)
                                .update(quizData);
                          } else {
                            await FirebaseFirestore.instance
                                .collection('quizzes')
                                .add(quizData);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Lỗi lưu: $e')));
                          }
                        } finally {
                          setStateDialog(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Lưu',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDeleteQuiz(BuildContext context, String quizId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa Quiz?',
            style: TextStyle(
                color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa quiz "$title"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('quizzes')
                  .doc(quizId)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Đã xóa quiz!'),
                    backgroundColor: Colors.red));
              }
            },
            child:
                const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Quản lý Quiz',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuizDialog(context),
        backgroundColor: const Color(0xFF00B4D8),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tạo Quiz',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF2C3E50)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Chưa có quiz nào.',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showQuizDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Tạo Quiz đầu tiên',
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }

          final quizzes = snapshot.data!.docs
              .map((doc) => Quiz.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding:
                const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              final isPron = quiz.type == QuizType.pronunciation;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // TYPE ICON
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPron
                                ? [
                                    const Color(0xFF2C3E50),
                                    const Color(0xFF3D566E)
                                  ]
                                : [
                                    const Color(0xFF00B4D8),
                                    const Color(0xFF0077B6)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPron
                              ? Icons.mic_rounded
                              : Icons.hearing_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // INFO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(quiz.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF2C3E50))),
                            const SizedBox(height: 3),
                            Text(
                              isPron
                                  ? '🎙 Phát âm: "${quiz.targetText}"'
                                  : '🎧 MCQ: ${quiz.options.length} lựa chọn',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7F8C8D)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (quiz.audioUrl.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async => await _audioPlayer
                                    .play(UrlSource(quiz.audioUrl)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.play_circle_outline,
                                        size: 14,
                                        color: Color(0xFF00B4D8)),
                                    SizedBox(width: 4),
                                    Text('Nghe audio',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF00B4D8),
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // ACTIONS
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showQuizDialog(context, quiz: quiz);
                          } else if (value == 'delete') {
                            _confirmDeleteQuiz(
                                context, quiz.id, quiz.title);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Sửa')
                              ])),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa',
                                    style: TextStyle(color: Colors.red))
                              ])),
                        ],
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

