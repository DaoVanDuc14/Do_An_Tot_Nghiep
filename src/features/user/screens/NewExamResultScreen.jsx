import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiCheckCircle, FiXCircle, FiClock, FiHome } from 'react-icons/fi';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function NewExamResultScreen() {
  const location = useLocation();
  const navigate = useNavigate();
  const { paper, questions, answers, correctCount, timeSpentSeconds, isAutoSubmit } = location.state || {};
  const [saved, setSaved] = useState(false);

  const total = questions?.length || 0;
  const score = correctCount * 10;
  const maxScore = total * 10;
  const pct = total > 0 ? Math.round((correctCount / total) * 100) : 0;

  useEffect(() => {
    if (saved || !paper) return;
    const saveResult = async () => {
      const user = auth.currentUser;
      if (!user) return;
      try {
        await FS.saveExamResultDetailed({
          userId: user.uid,
          name: user.displayName || user.email || 'Ẩn danh',
          examPaperId: paper.id,
          score,
          totalQuestions: total,
          answers,
          durationSeconds: timeSpentSeconds,
          isAutoSubmit: isAutoSubmit || false,
        });
      } catch (e) { console.error('Save result error:', e); }
      setSaved(true);
    };
    saveResult();
  }, [saved, paper, score, total, answers, timeSpentSeconds, isAutoSubmit]);

  const fmtTime = (s) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m} phút ${sec} giây`;
  };

  if (!paper) {
    return (
      <div className="loading-center" style={{ minHeight: '100vh', flexDirection: 'column' }}>
        <p>Không tìm thấy kết quả.</p>
        <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => navigate('/home')}>Về trang chủ</button>
      </div>
    );
  }

  const color = pct >= 80 ? AppColors.success : pct >= 50 ? AppColors.warning : AppColors.error;

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, padding: 20 }}>
      <div style={{ maxWidth: 480, margin: '0 auto' }}>
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          style={{ textAlign: 'center', marginBottom: 24 }}
        >
          {isAutoSubmit && (
            <div style={{ padding: '8px 16px', borderRadius: 8, background: '#FFF3E0', color: '#E65100', fontWeight: 600, fontSize: 13, marginBottom: 12, display: 'inline-block' }}>
              ⏰ Hết giờ - Bài thi đã được nộp tự động
            </div>
          )}
          <h2 style={{ color: AppColors.primary }}>{paper.title}</h2>
        </motion.div>

        {/* Score card */}
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="card"
          style={{ textAlign: 'center', marginBottom: 20, padding: 32 }}
        >
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.4, type: 'spring', bounce: 0.4 }}
            style={{
              width: 120, height: 120, borderRadius: '50%', margin: '0 auto 20px',
              background: `${color}15`, border: `4px solid ${color}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column',
            }}
          >
            <span style={{ fontSize: 36, fontWeight: 900, color }}>{score}</span>
            <span style={{ fontSize: 12, color: AppColors.textSecondary }}>/ {maxScore} điểm</span>
          </motion.div>

          <div style={{ display: 'flex', justifyContent: 'center', gap: 24, flexWrap: 'wrap' }}>
            <div style={{ textAlign: 'center' }}>
              <FiCheckCircle size={20} color={AppColors.success} />
              <p style={{ fontWeight: 700, color: AppColors.success }}>{correctCount}</p>
              <p style={{ fontSize: 12, color: AppColors.textSecondary }}>Đúng</p>
            </div>
            <div style={{ textAlign: 'center' }}>
              <FiXCircle size={20} color={AppColors.error} />
              <p style={{ fontWeight: 700, color: AppColors.error }}>{total - correctCount}</p>
              <p style={{ fontSize: 12, color: AppColors.textSecondary }}>Sai</p>
            </div>
            <div style={{ textAlign: 'center' }}>
              <FiClock size={20} color={AppColors.primary} />
              <p style={{ fontWeight: 700, color: AppColors.primary }}>{fmtTime(timeSpentSeconds)}</p>
              <p style={{ fontSize: 12, color: AppColors.textSecondary }}>Thời gian</p>
            </div>
          </div>
        </motion.div>

        {/* Detail per question */}
        <h3 style={{ color: AppColors.primary, marginBottom: 12 }}>Chi tiết từng câu</h3>
        {questions.map((q, i) => {
          const ans = answers[q.id];
          const isCorrect = ans?.isCorrect;
          return (
            <motion.div
              key={q.id}
              initial={{ opacity: 0, x: 10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3 + i * 0.05 }}
              className="card"
              style={{
                padding: 14, marginBottom: 10,
                borderLeft: `4px solid ${isCorrect ? AppColors.success : ans ? AppColors.error : AppColors.textLight}`,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontWeight: 700, color: AppColors.textSecondary, fontSize: 13, minWidth: 36 }}>Câu {i + 1}</span>
                <span className={`badge ${q.type === 'mcq' ? 'badge-accent' : 'badge-primary'}`} style={{ fontSize: 11 }}>
                  {q.type === 'mcq' ? '🎧 Nghe' : '🎙 Phát âm'}
                </span>
                <div style={{ flex: 1 }} />
                {isCorrect ? <FiCheckCircle color={AppColors.success} size={18} /> : ans ? <FiXCircle color={AppColors.error} size={18} /> : <span style={{ fontSize: 12, color: AppColors.textLight }}>Bỏ qua</span>}
              </div>
              <p style={{ fontSize: 14, color: AppColors.textPrimary, marginTop: 6 }}>{q.targetText}</p>
              {ans?.type === 'mcq' && (
                <p style={{ fontSize: 13, color: isCorrect ? AppColors.success : AppColors.error, marginTop: 4 }}>
                  Chọn: {ans.selected} {!isCorrect && `→ Đáp án: ${q.correctAnswer}`}
                </p>
              )}
              {ans?.type === 'pronunciation' && (
                <p style={{ fontSize: 13, color: isCorrect ? AppColors.success : AppColors.error, marginTop: 4 }}>
                  Độ chính xác: {ans.accuracy}%
                </p>
              )}
            </motion.div>
          );
        })}

        {/* Home button */}
        <button
          className="btn btn-primary"
          style={{ width: '100%', padding: 16, marginTop: 20, marginBottom: 40 }}
          onClick={() => navigate('/home')}
        >
          <FiHome size={18} /> Về trang chủ
        </button>
      </div>
    </div>
  );
}
