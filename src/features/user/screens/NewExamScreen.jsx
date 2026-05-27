import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiArrowLeft, FiArrowRight, FiGrid, FiPlay, FiClock, FiMic, FiHeadphones, FiCheckCircle, FiXCircle } from 'react-icons/fi';
import { MdAssignment } from 'react-icons/md';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';
import { getTtsUrl } from '../../../services/pronunciationService';
import PronunciationRecorderWidget from '../../shared/PronunciationRecorderWidget';

export default function NewExamScreen() {
  const { paperId } = useParams();
  const navigate = useNavigate();
  const [paper, setPaper] = useState(null);
  const [questions, setQuestions] = useState([]);
  const [started, setStarted] = useState(false);
  const [idx, setIdx] = useState(0);
  const [answers, setAnswers] = useState({});
  const [remaining, setRemaining] = useState(0);
  const [loading, setLoading] = useState(true);
  const [showGrid, setShowGrid] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [isAudioPlaying, setIsAudioPlaying] = useState(false);
  const timerRef = useRef(null);
  const audioRef = useRef(new Audio());

  useEffect(() => {
    const loadData = async () => {
      const p = await FS.getExamPaperById(paperId);
      if (!p) { navigate('/home'); return; }
      const duration = p.durationMinutes || p.duration_minutes || 30;
      setPaper(p);
      setRemaining(duration * 60);
      const qs = await FS.getExamQuestions(paperId);
      setQuestions(qs);
      setLoading(false);
    };
    loadData();
    return () => { timerRef.current && clearInterval(timerRef.current); audioRef.current.pause(); };
  }, [paperId, navigate]);

  const submit = useCallback((autoSubmit = false) => {
    timerRef.current && clearInterval(timerRef.current);
    let correct = 0;
    questions.forEach(q => { if (answers[q.id]?.isCorrect) correct++; });
    const duration = paper?.durationMinutes || paper?.duration_minutes || 30;
    const spent = duration * 60 - remaining;
    navigate('/exam-result', {
      state: { paper, questions, answers, correctCount: correct, timeSpentSeconds: spent, isAutoSubmit: autoSubmit },
      replace: true,
    });
  }, [answers, questions, paper, remaining, navigate]);

  useEffect(() => {
    if (started && remaining <= 0) {
      submit(true);
    }
  }, [remaining, started, submit]);

  const startExam = () => {
    setStarted(true);
    timerRef.current = setInterval(() => {
      setRemaining(prev => {
        if (prev <= 1) {
          clearInterval(timerRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const fmt = (s) => {
    if (isNaN(s)) return "00:00";
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  };

  const selectMcq = (q, option) => {
    if (answers[q.id]) return;
    setAnswers(prev => ({
      ...prev,
      [q.id]: { type: 'mcq', selected: option, isCorrect: option.trim().toLowerCase() === q.correctAnswer.trim().toLowerCase() },
    }));
  };

  const onPronResult = (q, result) => {
    setAnswers(prev => ({
      ...prev,
      [q.id]: { type: 'pronunciation', accuracy: result.accuracy, isCorrect: result.passed },
    }));
  };

  const playAudio = (text) => {
    if (isAudioPlaying) { audioRef.current.pause(); setIsAudioPlaying(false); return; }
    setIsAudioPlaying(true);
    audioRef.current.src = getTtsUrl(text);
    audioRef.current.onended = () => setIsAudioPlaying(false);
    audioRef.current.onerror = () => setIsAudioPlaying(false);
    audioRef.current.play().catch(() => setIsAudioPlaying(false));
  };

  if (loading) return <div className="loading-center" style={{ minHeight: '100vh' }}><div className="spinner" /></div>;

  // ── Start Screen ──
  if (!started) {
    const duration = paper?.durationMinutes || paper?.duration_minutes || 30;
    return (
      <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
        <div style={{ textAlign: 'center', maxWidth: 400 }}>
          <div style={{ width: 100, height: 100, borderRadius: '50%', background: 'linear-gradient(135deg, #0D47A1, #1976D2)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px' }}>
            <MdAssignment size={52} color="white" />
          </div>
          <h2 style={{ color: AppColors.primary, marginBottom: 24 }}>{paper?.title}</h2>
          {[
            ['❓', `${questions.length} câu hỏi`],
            ['⏱️', `${duration} phút`],
            ['⭐', '10 điểm / câu đúng'],
            ['🎙️', 'Phát âm: thu âm & chấm AI (≥80% = đạt)'],
          ].map(([icon, text], i) => (
            <p key={i} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, color: AppColors.textSecondary, fontSize: 15, marginBottom: 10 }}>
              <span>{icon}</span> {text}
            </p>
          ))}
          <button className="btn btn-primary" style={{ width: '100%', padding: 16, fontSize: 18, marginTop: 30 }} onClick={startExam}>
            <FiPlay size={24} /> Bắt đầu làm bài
          </button>
        </div>
      </div>
    );
  }

  // ── Exam Screen ──
  const q = questions[idx];
  const isMcq = q?.type === 'mcq';
  const total = questions.length;
  const answered = Object.keys(answers).length;
  const timerColor = remaining < 60 ? '#F44336' : remaining < 300 ? '#FF9800' : 'white';

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      {/* Top bar */}
      <div style={{ background: AppColors.primary, color: 'white', padding: '10px 16px' }}>
        <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', alignItems: 'center' }}>
          <div style={{ padding: '4px 10px', borderRadius: 20, background: remaining < 60 ? 'rgba(244,67,54,0.2)' : 'rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', gap: 4 }}>
            <FiClock size={16} color={timerColor} />
            <span style={{ color: timerColor, fontWeight: 700 }}>{fmt(remaining)}</span>
          </div>
          <div style={{ flex: 1, textAlign: 'center', fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', padding: '0 8px' }}>{paper?.title}</div>
          <button onClick={() => setShowConfirm(true)} style={{ padding: '6px 14px', borderRadius: 20, background: 'white', color: AppColors.primary, fontWeight: 700, fontSize: 13, border: 'none', cursor: 'pointer' }}>
            Nộp bài
          </button>
        </div>
        {/* Progress */}
        <div style={{ maxWidth: 800, margin: '8px auto 0' }}>
          <div style={{ height: 6, background: 'rgba(255,255,255,0.24)', borderRadius: 3 }}>
            <div style={{ height: '100%', width: `${(answered / total) * 100}%`, background: AppColors.accent, borderRadius: 3, transition: 'width 0.3s' }} />
          </div>
        </div>
      </div>

      {/* Question grid */}
      <div style={{ background: AppColors.surface, borderBottom: '1px solid #E0E0E0' }}>
        <div style={{ maxWidth: 800, margin: '0 auto', padding: '10px 16px', overflowX: 'auto', display: 'flex', gap: 8 }}>
          {questions.map((qq, i) => {
            const isAnswered = !!answers[qq.id];
            const isCurrent = i === idx;
            return (
              <button key={qq.id} onClick={() => setIdx(i)} style={{
                width: 38, height: 38, borderRadius: 8, border: isCurrent ? `2px solid ${AppColors.primary}` : 'none',
                background: isCurrent ? AppColors.primary : isAnswered ? AppColors.accent : '#E0E0E0',
                color: isCurrent || isAnswered ? 'white' : '#757575',
                fontWeight: 700, fontSize: 14, cursor: 'pointer', flexShrink: 0,
              }}>
                {i + 1}
              </button>
            );
          })}
        </div>
      </div>

      {/* Question content */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '24px 16px' }}>
        <div style={{ maxWidth: 800, margin: '0 auto' }}>
          <div className="card" style={{ marginBottom: 20 }}>
          <div style={{ textAlign: 'center', marginBottom: 14 }}>
            <span className={`badge ${isMcq ? 'badge-accent' : 'badge-primary'}`}>
              {isMcq ? '🎧 Luyện nghe' : '🎙 Phát âm'}
            </span>
          </div>
          <p style={{ textAlign: 'center', fontSize: 13, color: AppColors.textSecondary }}>Câu {idx + 1} / {total}</p>

          {isMcq ? (
            <div style={{ textAlign: 'center', padding: '24px 0' }}>
              <p style={{ color: AppColors.textSecondary, fontSize: 14, marginBottom: 16 }}>Nhấn vào nút bên dưới để nghe âm thanh</p>
              <motion.button
                whileTap={{ scale: 0.9 }}
                onClick={() => playAudio(q.targetText)}
                style={{
                  width: 80, height: 80, borderRadius: '50%', border: 'none',
                  background: isAudioPlaying ? AppColors.accent : AppColors.primary,
                  color: 'white', cursor: 'pointer',
                  boxShadow: `0 6px 16px ${isAudioPlaying ? 'rgba(0,180,216,0.3)' : 'rgba(21,101,192,0.3)'}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  margin: '0 auto'
                }}
              >
                {isAudioPlaying ? (
                  <FiHeadphones size={36} />
                ) : (
                  <FiPlay size={36} style={{ marginLeft: 6 }} />
                )}
              </motion.button>
            </div>
          ) : (
            <div style={{
              padding: 16, borderRadius: 14, margin: '14px 0',
              background: 'rgba(21,101,192,0.06)', border: '1px solid rgba(21,101,192,0.2)', textAlign: 'center',
            }}>
              <p style={{ fontSize: 13, color: AppColors.textSecondary }}>Hãy đọc câu sau:</p>
              <p style={{ fontSize: 24, fontWeight: 700, color: AppColors.primary, lineHeight: 1.4, marginTop: 8 }}>{q.targetText}</p>
            </div>
          )}
        </div>

        {/* MCQ options */}
        {isMcq && q.options?.map((opt, i) => {
          const ansData = answers[q.id];
          const hasAnswered = !!ansData;
          const isSelected = ansData?.selected === opt;
          const isCorrectOpt = opt.trim().toLowerCase() === q.correctAnswer.trim().toLowerCase();
          let bg = AppColors.surface, border = '#E0E0E0', textColor = AppColors.textPrimary, icon = null;

          if (hasAnswered) {
            if (isCorrectOpt) { bg = '#E8F5E9'; border = '#4CAF50'; textColor = '#2E7D32'; icon = <FiCheckCircle size={20} color="#4CAF50" />; }
            else if (isSelected) { bg = '#FFEBEE'; border = '#F44336'; textColor = '#C62828'; icon = <FiXCircle size={20} color="#F44336" />; }
            else { textColor = '#9E9E9E'; }
          }

          return (
            <motion.button
              key={i}
              whileTap={!hasAnswered ? { scale: 0.98 } : {}}
              onClick={() => selectMcq(q, opt)}
              style={{
                width: '100%', padding: '14px 16px', marginBottom: 10, borderRadius: 14,
                border: `2px solid ${border}`, background: bg, cursor: hasAnswered ? 'default' : 'pointer',
                display: 'flex', alignItems: 'center', gap: 14, textAlign: 'left',
              }}
            >
              <div style={{
                width: 32, height: 32, borderRadius: '50%', flexShrink: 0,
                background: hasAnswered && (isCorrectOpt || isSelected) ? (isCorrectOpt ? '#4CAF50' : '#F44336') : '#F5F5F5',
                border: `1px solid ${hasAnswered && (isCorrectOpt || isSelected) ? 'transparent' : '#E0E0E0'}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: hasAnswered && (isCorrectOpt || isSelected) ? 'white' : '#757575', fontWeight: 700,
              }}>
                {String.fromCharCode(65 + i)}
              </div>
              <span style={{ flex: 1, fontSize: 15, color: textColor, fontWeight: hasAnswered && (isCorrectOpt || isSelected) ? 700 : 400 }}>{opt}</span>
              {icon}
            </motion.button>
          );
        })}

        {/* Pronunciation recorder */}
        {!isMcq && (
          <PronunciationRecorderWidget
            key={`pron_${q.id}`}
            targetText={q.targetText}
            recordId={q.id}
            initialResult={answers[q.id]?.type === 'pronunciation' ? { targetText: q.targetText, recognizedText: '', accuracy: answers[q.id].accuracy || 0, passed: answers[q.id].isCorrect || false } : null}
            onResult={(result) => onPronResult(q, result)}
          />
        )}
        </div>
      </div>

      {/* Bottom nav */}
      <div style={{ background: AppColors.surface, boxShadow: '0 -2px 8px rgba(0,0,0,0.05)' }}>
        <div style={{ maxWidth: 800, margin: '0 auto', padding: '10px 16px 20px', display: 'flex', gap: 12, alignItems: 'center' }}>
          <button className="btn btn-secondary" style={{ flex: 1, padding: 14 }} disabled={idx === 0} onClick={() => setIdx(idx - 1)}>
            <FiArrowLeft size={16} /> Trước
          </button>
          <button className="btn-icon" style={{ width: 48, height: 48 }} onClick={() => setShowGrid(true)}>
            <FiGrid size={20} color={AppColors.primary} />
          </button>
          <button className="btn btn-primary" style={{ flex: 1, padding: 14 }} onClick={() => idx < total - 1 ? setIdx(idx + 1) : setShowConfirm(true)}>
            {idx < total - 1 ? <><FiArrowRight size={16} /> Tiếp theo</> : '✓ Nộp bài'}
          </button>
        </div>
      </div>

      {/* Grid Sheet */}
      <AnimatePresence>
        {showGrid && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowGrid(false)}>
            <motion.div className="modal-content" initial={{ y: 100 }} animate={{ y: 0 }} exit={{ y: 100 }} onClick={e => e.stopPropagation()} style={{ maxHeight: '60vh', overflow: 'auto' }}>
              <h3 className="modal-title">Danh sách câu hỏi</h3>
              <p style={{ color: AppColors.textSecondary, fontSize: 13, marginBottom: 16 }}>Đã làm: {answered}/{total}</p>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 8 }}>
                {questions.map((qq, i) => {
                  const isA = !!answers[qq.id];
                  const isC = i === idx;
                  return (
                    <button key={qq.id} onClick={() => { setIdx(i); setShowGrid(false); }} style={{
                      aspectRatio: 1, borderRadius: 10, border: 'none', cursor: 'pointer', fontWeight: 700,
                      background: isC ? AppColors.primary : isA ? AppColors.accent : '#E0E0E0',
                      color: isC || isA ? 'white' : '#757575',
                    }}>
                      {i + 1}
                    </button>
                  );
                })}
              </div>
              <div style={{ display: 'flex', justifyContent: 'center', gap: 16, marginTop: 14 }}>
                {[['Đang làm', AppColors.primary], ['Đã làm', AppColors.accent], ['Chưa làm', '#E0E0E0']].map(([label, color]) => (
                  <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                    <div style={{ width: 14, height: 14, borderRadius: 4, background: color }} />
                    <span style={{ fontSize: 12 }}>{label}</span>
                  </div>
                ))}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Submit Confirm */}
      <AnimatePresence>
        {showConfirm && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowConfirm(false)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title">Nộp bài?</h3>
              <p>📝 Tổng số câu: {total}</p>
              <p>✅ Đã làm: {answered}</p>
              {total - answered > 0 && <p style={{ color: '#FF9800', fontWeight: 700 }}>⚠️ Chưa làm: {total - answered}</p>}
              {total === answered && <p style={{ color: '#4CAF50' }}>✅ Đã hoàn thành tất cả!</p>}
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setShowConfirm(false)}>Tiếp tục làm</button>
                <button className="btn btn-primary" onClick={() => submit(false)}>Nộp bài</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
