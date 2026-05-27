import { useState, useRef, useCallback } from 'react';
import { motion } from 'framer-motion';
import { FiMic, FiSquare, FiVolume2, FiRefreshCw } from 'react-icons/fi';
import { evaluate, getTtsUrl } from '../../services/pronunciationService';
import { AppColors } from '../../core/constants/appColors';

export default function PronunciationRecorderWidget({
  targetText, recordId, initialResult = null, onResult, showListenSample = true,
}) {
  const [isRecording, setIsRecording] = useState(false);
  const [isScoring, setIsScoring] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [result, setResult] = useState(initialResult);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const audioRef = useRef(new Audio());

  // ── TTS Playback ──
  const playTTS = useCallback(() => {
    if (isPlaying) {
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
      setIsPlaying(false);
      return;
    }
    setIsPlaying(true);
    const audio = audioRef.current;
    audio.src = getTtsUrl(targetText);
    audio.onended = () => setIsPlaying(false);
    audio.onerror = () => setIsPlaying(false);
    audio.play().catch(() => setIsPlaying(false));
  }, [targetText, isPlaying]);

  // ── Recording ──
  const toggleRecording = useCallback(async () => {
    if (isRecording) {
      // Stop
      mediaRecorderRef.current?.stop();
      setIsRecording(false);
    } else {
      // Start
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const mediaRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm' });
        chunksRef.current = [];
        mediaRecorder.ondataavailable = (e) => {
          if (e.data.size > 0) chunksRef.current.push(e.data);
        };
        mediaRecorder.onstop = async () => {
          stream.getTracks().forEach(t => t.stop());
          const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
          await score(blob);
        };
        mediaRecorder.start();
        mediaRecorderRef.current = mediaRecorder;
        setIsRecording(true);
        setResult(null);
      } catch (err) {
        console.error('Mic access denied:', err);
      }
    }
  }, [isRecording, targetText]);

  // ── Score ──
  const score = async (blob) => {
    setIsScoring(true);
    try {
      const res = await evaluate(targetText, blob);
      setResult(res);
      onResult?.(res);
    } catch (err) {
      console.error('Score error:', err);
    } finally {
      setIsScoring(false);
    }
  };

  // ── Word highlighting ──
  const renderWords = () => {
    if (!result || !result.recognizedText) return null;
    const targetWords = result.targetText.split(/\s+/);
    const recognizedWords = result.recognizedText.split(/\s+/);

    return (
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center', marginBottom: 24 }}>
        {recognizedWords.map((word, i) => {
          const isCorrect = i < targetWords.length && word === targetWords[i];
          return (
            <span key={i} style={{
              fontSize: 22, fontWeight: 700,
              color: isCorrect ? '#4CAF50' : '#EF5350',
              textDecoration: isCorrect ? 'none' : 'underline',
              textDecorationColor: '#EF5350',
              textUnderlineOffset: 4,
            }}>
              {word}
            </span>
          );
        })}
      </div>
    );
  };

  // ── Accuracy badge color ──
  const getBadgeColor = (acc) => {
    if (acc >= 80) return { bg: '#E8F5E9', border: '#4CAF50', text: '#2E7D32' };
    if (acc >= 50) return { bg: '#FFF3E0', border: '#FF9800', text: '#E65100' };
    return { bg: '#FFEBEE', border: '#EF5350', text: '#C62828' };
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      {/* Result text */}
      {!result && !isScoring && (
        <p style={{ color: '#999', fontSize: 16, fontStyle: 'italic', marginBottom: 24 }}>
          Bấm nút ghi âm để bắt đầu đọc...
        </p>
      )}
      {result && renderWords()}

      {/* Buttons */}
      {isScoring ? (
        <div style={{ textAlign: 'center' }}>
          <div className="spinner" style={{ margin: '0 auto 8px' }} />
          <p style={{ color: AppColors.textSecondary }}>Đang chấm điểm...</p>
        </div>
      ) : (
        <div style={{ display: 'flex', gap: 50, alignItems: 'flex-start' }}>
          {showListenSample && (
            <div style={{ textAlign: 'center' }}>
              <motion.button
                whileTap={{ scale: 0.9 }}
                onClick={playTTS}
                style={{
                  width: 64, height: 64, borderRadius: '50%', border: 'none',
                  background: '#2196F3', color: 'white', cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: '0 6px 12px rgba(33,150,243,0.3)',
                }}
              >
                {isPlaying ? <FiSquare size={28} /> : <FiVolume2 size={28} />}
              </motion.button>
              <p style={{ marginTop: 10, fontWeight: 700, fontSize: 14, color: '#2196F3' }}>Nghe mẫu</p>
            </div>
          )}

          <div style={{ textAlign: 'center' }}>
            <motion.button
              whileTap={{ scale: 0.9 }}
              animate={isRecording ? { scale: [1, 1.1, 1] } : {}}
              transition={isRecording ? { repeat: Infinity, duration: 1 } : {}}
              onClick={toggleRecording}
              style={{
                width: 64, height: 64, borderRadius: '50%', border: 'none',
                background: isRecording ? '#F44336' : '#00B4D8', color: 'white',
                cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: `0 6px 12px ${isRecording ? 'rgba(244,67,54,0.3)' : 'rgba(0,180,216,0.3)'}`,
              }}
            >
              {isRecording ? <FiSquare size={28} /> : <FiMic size={28} />}
            </motion.button>
            <p style={{
              marginTop: 10, fontWeight: 700, fontSize: 14,
              color: isRecording ? '#F44336' : '#00B4D8',
            }}>
              {isRecording ? 'Dừng' : 'Ghi âm'}
            </p>
          </div>
        </div>
      )}

      {/* Accuracy result */}
      {result && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          style={{ textAlign: 'center', marginTop: 24 }}
        >
          <div style={{
            display: 'inline-block', padding: '12px 24px',
            borderRadius: 30,
            background: getBadgeColor(result.accuracy).bg,
            border: `2px solid ${getBadgeColor(result.accuracy).border}`,
          }}>
            <span style={{
              fontSize: 18, fontWeight: 700,
              color: getBadgeColor(result.accuracy).text,
            }}>
              Độ chính xác: {result.accuracy}%
            </span>
          </div>

          <button
            onClick={() => setResult(null)}
            style={{
              display: 'flex', alignItems: 'center', gap: 6,
              margin: '16px auto 0', background: 'none', border: 'none',
              color: AppColors.primary, fontWeight: 600, cursor: 'pointer',
              fontSize: 14, fontFamily: 'Roboto, sans-serif',
            }}
          >
            <FiRefreshCw size={16} /> Thu âm lại
          </button>
        </motion.div>
      )}
    </div>
  );
}
