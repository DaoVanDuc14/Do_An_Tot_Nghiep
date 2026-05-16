import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/pronunciation_service.dart';

/// Widget dùng chung cho thu âm + chấm phát âm.
/// Dùng trong cả PracticeScreen và ExamTakingScreen.
class PronunciationRecorderWidget extends StatefulWidget {
  final String targetText;
  final String recordId; // unique key để tạo filename
  final PronunciationResult? initialResult;
  final ValueChanged<PronunciationResult>? onResult;
  final bool showListenSample; // hiện nút "Nghe mẫu" TTS

  const PronunciationRecorderWidget({
    super.key,
    required this.targetText,
    required this.recordId,
    this.initialResult,
    this.onResult,
    this.showListenSample = true,
  });

  @override
  State<PronunciationRecorderWidget> createState() =>
      _PronunciationRecorderWidgetState();
}

class _PronunciationRecorderWidgetState
    extends State<PronunciationRecorderWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isScoring = false;
  bool _isPlaying = false;
  PronunciationResult? _result;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  @override
  void didUpdateWidget(covariant PronunciationRecorderWidget old) {
    super.didUpdateWidget(old);
    if (old.recordId != widget.recordId) {
      // Dừng recorder/player nếu đang chạy khi chuyển câu
      _stopAll();
      _result = widget.initialResult;
      _isRecording = false;
      _isScoring = false;
      _isPlaying = false;
    }
  }

  /// Dừng tất cả recorder/player — gọi khi chuyển câu hoặc dispose
  Future<void> _stopAll() async {
    try { await _recorder.stop(); } catch (_) {}
    try { await _player.stop(); } catch (_) {}
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playTTS() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    try {
      final url =
          '${AppStrings.ttsEndpoint}?text=${Uri.encodeComponent(widget.targetText)}';
      await _player.play(UrlSource(url));
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) _score(path);
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
          path: '${dir.path}/rec_${widget.recordId}.wav',
        );
        setState(() {
          _isRecording = true;
          _result = null;
        });
      }
    }
  }

  Future<void> _score(String filePath) async {
    setState(() => _isScoring = true);
    try {
      final result = await PronunciationService.evaluate(
        targetText: widget.targetText,
        audioFilePath: filePath,
      );
      if (mounted) {
        setState(() => _result = result);
        widget.onResult?.call(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScoring = false);
    }
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap, required String label}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 64, width: 64,
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle, 
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))
              ]
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildRecognizedWords() {
    if (_result == null || _result!.recognizedText.isEmpty) return const SizedBox.shrink();

    String targetText = _result!.targetText.toLowerCase();
    String recognizedText = _result!.recognizedText.toLowerCase();

    List<String> targetWords = targetText.split(' ');
    List<String> recognizedWords = recognizedText.split(' ');

    List<Widget> wordSpans = [];

    for (int i = 0; i < recognizedWords.length; i++) {
      String word = recognizedWords[i];
      bool isCorrect = i < targetWords.length && word == targetWords[i];

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

    return Column(
      children: [
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: wordSpans),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Kết quả text (chữ màu xanh/đỏ)
      if (_result == null && !_isScoring)
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Text('Bấm nút ghi âm để bắt đầu đọc...', style: TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic)),
        )
      else if (_result != null)
        _buildRecognizedWords(),

      // Nút thu âm và nghe mẫu
      if (_isScoring)
        const Column(children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          ),
          SizedBox(height: 8),
          Text('Đang chấm điểm...',
              style: TextStyle(color: AppColors.textSecondary)),
        ])
      else
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showListenSample) ...[
              _buildActionButton(
                icon: _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded, 
                color: Colors.blue, 
                onTap: _playTTS, 
                label: "Nghe mẫu"
              ),
              const SizedBox(width: 50),
            ],
            _buildActionButton(
              icon: _isRecording ? Icons.stop_rounded : Icons.mic_rounded, 
              color: _isRecording ? Colors.red : const Color(0xFF00B4D8), 
              onTap: _toggleRecording, 
              label: _isRecording ? "Dừng" : "Ghi âm"
            ),
          ],
        ),

      // Kết quả
      if (_result != null) ...[
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _result!.accuracy >= 80 ? Colors.green[50] : (_result!.accuracy >= 50 ? Colors.orange[50] : Colors.red[50]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _result!.accuracy >= 80 ? Colors.green : (_result!.accuracy >= 50 ? Colors.orange : Colors.red),
              width: 1.5,
            ),
          ),
          child: Text(
            'Độ chính xác: ${_result!.accuracy}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _result!.accuracy >= 80 ? Colors.green[700] : (_result!.accuracy >= 50 ? Colors.orange[800] : Colors.red[700]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _isScoring
              ? null
              : () => setState(() {
                    _result = null;
                  }),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Thu âm lại'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    ]);
  }
}
