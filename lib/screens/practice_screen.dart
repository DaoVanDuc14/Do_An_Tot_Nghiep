import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sentence.dart';

class PracticeScreen extends StatefulWidget {
  final Sentence sentence;

  const PracticeScreen({super.key, required this.sentence});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isLoading = false;
  Map<String, dynamic>? _resultData;

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // NGHE MẪU (Đảm bảo IP đúng)
  Future<void> _playSample() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://vanduc14-vku-pronunciation-api.hf.space/api/v1/tts?text=${widget.sentence.text}');
      await _audioPlayer.play(UrlSource(url.toString()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi TTS: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // GHI ÂM VÀ LƯU FILE TẠM
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) _sendToAI(path);
    } else {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/record.wav';
        const config = RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000);
        await _recorder.start(config, path: path);
        setState(() {
          _isRecording = true;
          _resultData = null;
        });
      }
    }
  }

  // LƯU ĐIỂM SỐ LÊN FIREBASE KHI ĐỌC XONG
  Future<void> _saveProgress(int accuracy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ Lỗi: Chưa đăng nhập, không thể lưu điểm!");
      return;
    }

    final progressId = "${user.uid}_${widget.sentence.id}";
    print("📡 Đang cố gắng lưu điểm: $accuracy% cho câu ${widget.sentence.id}");

    try {
      await FirebaseFirestore.instance.collection('user_progress').doc(progressId).set({
        'uid': user.uid,
        'sentenceId': widget.sentence.id,
        'topicId': widget.sentence.topicId,
        'score': accuracy,
        'lastUpdated': Timestamp.now(),
      });
      print("✅ Đã lưu điểm lên Firebase thành công!");
    } catch (e) {
      print("❌ Lỗi Firebase: $e");
    }
  }

  // GỬI FILE FILE CHO FASTAPI VÀ NHẬN KẾT QUẢ
  Future<void> _sendToAI(String filePath) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://vanduc14-vku-pronunciation-api.hf.space/api/v1/evaluate'));
      request.fields['target_text'] = widget.sentence.text;
      request.files.add(await http.MultipartFile.fromPath('audio_file', filePath));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody)['data'];
        setState(() => _resultData = data);

        // TÍNH TOÁN ĐIỂM VÀ LƯU VÀO FIREBASE
        String targetText = data['target_text'].toString().toLowerCase();
        String recognizedText = data['recognized_text'].toString().toLowerCase();
        List<String> targetWords = targetText.split(' ');
        List<String> recognizedWords = recognizedText.split(' ');

        int correctCount = 0;
        for (int i = 0; i < recognizedWords.length; i++) {
          if (i < targetWords.length && recognizedWords[i] == targetWords[i]) {
            correctCount++;
          }
        }
        int accuracy = targetWords.isEmpty ? 0 : ((correctCount / targetWords.length) * 100).round();
        if (accuracy > 100) accuracy = 100;

        // Gọi hàm lưu điểm
        await _saveProgress(accuracy);
        setState(() => _isLoading = false);

      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi Server: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể kết nối AI: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // KHU VỰC HIỂN THỊ CHỮ VÀ TÍNH ĐIỂM TRÊN UI
  Widget _buildResultArea() {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xFF2C3E50)));
    }

    if (_resultData == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('Bấm nút ghi âm để bắt đầu đọc...', style: TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic)),
      );
    }

    String targetText = _resultData!['target_text'].toString().toLowerCase();
    String recognizedText = _resultData!['recognized_text'].toString().toLowerCase();

    List<String> targetWords = targetText.split(' ');
    List<String> recognizedWords = recognizedText.split(' ');

    int correctCount = 0;
    List<Widget> wordSpans = [];

    for (int i = 0; i < recognizedWords.length; i++) {
      String word = recognizedWords[i];
      bool isCorrect = i < targetWords.length && word == targetWords[i];

      if (isCorrect) correctCount++;

      wordSpans.add(
        Text(
          word,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
            decoration: isCorrect ? null : TextDecoration.underline,
            decorationColor: const Color(0xFFEF5350),
            decorationThickness: 2,
          ),
        ),
      );
    }

    int accuracy = targetWords.isEmpty ? 0 : ((correctCount / targetWords.length) * 100).round();
    if (accuracy > 100) accuracy = 100;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: wordSpans),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
              color: accuracy >= 80 ? Colors.green[50] : (accuracy >= 50 ? Colors.orange[50] : Colors.red[50]),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: accuracy >= 80 ? Colors.green : (accuracy >= 50 ? Colors.orange : Colors.red), width: 1.5)
          ),
          child: Text(
            'Độ chính xác: $accuracy%',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: accuracy >= 80 ? Colors.green[700] : (accuracy >= 50 ? Colors.orange[800] : Colors.red[700]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('Luyện Phát Âm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2C3E50),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey[200], height: 1.0)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
                ),
                child: Column(
                  children: [
                    const Text('Câu cần đọc', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                      widget.sentence.text.toLowerCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Kết quả nhận diện', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    _buildResultArea(),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(icon: Icons.volume_up_rounded, color: Colors.blue, onTap: _playSample, label: "Nghe mẫu"),
                  const SizedBox(width: 50),
                  _buildActionButton(icon: _isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isRecording ? Colors.red : const Color(0xFF00B4D8), onTap: _toggleRecording, label: _isRecording ? "Dừng" : "Ghi âm"),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap, required String label}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 64, width: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}