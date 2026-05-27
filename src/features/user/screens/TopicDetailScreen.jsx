import { useState, useEffect } from 'react';
import { useParams, useLocation, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiArrowLeft, FiPlus, FiMoreVertical, FiEdit2, FiTrash2, FiPlay } from 'react-icons/fi';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

function ScoreCircle({ score }) {
  const color = score === 0 ? AppColors.textLight : score >= 80 ? AppColors.success : score >= 50 ? AppColors.warning : AppColors.error;
  const circumference = 2 * Math.PI * 18;
  const offset = circumference - (score / 100) * circumference;

  return (
    <div className="score-circle">
      <svg viewBox="0 0 44 44">
        <circle cx="22" cy="22" r="18" fill="none" stroke={AppColors.background} strokeWidth="4" />
        <circle cx="22" cy="22" r="18" fill="none" stroke={color} strokeWidth="4"
          strokeDasharray={circumference} strokeDashoffset={offset} strokeLinecap="round" />
      </svg>
      <span className="score-text" style={{ color, fontSize: 13 }}>{score}</span>
    </div>
  );
}

export default function TopicDetailScreen() {
  const { id } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const topic = location.state?.topic || { id, title: 'Chủ đề' };
  const uid = auth.currentUser?.uid;
  const isOwner = uid === topic.uid;

  const [sentences, setSentences] = useState([]);
  const [scores, setScores] = useState({});
  const [loading, setLoading] = useState(true);
  const [showDialog, setShowDialog] = useState(false);
  const [editSentence, setEditSentence] = useState(null);
  const [vnText, setVnText] = useState('');
  const [enText, setEnText] = useState('');
  const [delSentence, setDelSentence] = useState(null);
  const [menuOpen, setMenuOpen] = useState(null);

  useEffect(() => {
    const unsub = FS.sentencesStream(id, (snap) => {
      setSentences(FS.parseSentences(snap));
      setLoading(false);
    });
    return unsub;
  }, [id]);

  // Listen to progress for each sentence
  useEffect(() => {
    if (!uid || sentences.length === 0) return;
    const unsubs = sentences.map(s =>
      FS.progressStream(uid, s.id, (snap) => {
        if (snap.exists()) {
          setScores(prev => ({ ...prev, [s.id]: snap.data().score || 0 }));
        }
      })
    );
    return () => unsubs.forEach(u => u());
  }, [uid, sentences]);

  const openDialog = (s = null) => {
    setEditSentence(s);
    setVnText(s?.vietnamese || '');
    setEnText(s?.english || '');
    setShowDialog(true);
  };

  const saveSentence = async () => {
    if (!vnText.trim()) return;
    if (editSentence) {
      await FS.updateSentence(editSentence.id, { vietnamese: vnText.trim(), english: enText.trim() });
    } else {
      await FS.createSentence({ vietnamese: vnText.trim(), english: enText.trim(), topicId: id, audioUrl: '' });
    }
    setShowDialog(false);
  };

  const handleDelete = async () => {
    if (delSentence) { await FS.deleteSentence(delSentence.id); setDelSentence(null); }
  };

  const scoreColor = (s) => {
    const sc = scores[s.id] || 0;
    if (sc === 0) return AppColors.textLight;
    if (sc >= 80) return AppColors.success;
    if (sc >= 50) return AppColors.warning;
    return AppColors.error;
  };

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>{topic.title}</h2>
        <div style={{ width: 48 }} />
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0', paddingBottom: 80 }}>
        <div className="page-container">
        {loading ? (
          <div className="loading-center"><div className="spinner" /></div>
        ) : sentences.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">🎤</div>
            <p>{isOwner ? 'Chưa có câu hỏi nào.\nHãy bấm nút + để thêm nhé!' : 'Tác giả chưa cập nhật câu hỏi.'}</p>
          </div>
        ) : (
          <div className="content-grid">
          {sentences.map((s, i) => (
            <motion.div
              key={s.id}
              initial={{ opacity: 0, x: 10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.05 }}
              className="card"
              style={{
                padding: 16, cursor: 'pointer',
                borderLeft: `4px solid ${scoreColor(s)}`, position: 'relative',
              }}
              onClick={() => navigate(`/practice/${s.id}`, { state: { sentence: s } })}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <div style={{
                  width: 44, height: 44, borderRadius: 14, flexShrink: 0,
                  background: `${scoreColor(s)}18`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <FiPlay size={22} color={scoreColor(s)} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ fontSize: 16, fontWeight: 600, color: AppColors.textPrimary }}>{s.vietnamese}</p>
                  {s.english && <p style={{ fontSize: 13, color: AppColors.textSecondary }}>{s.english}</p>}
                </div>
                <ScoreCircle score={scores[s.id] || 0} />
                {isOwner && (
                  <div style={{ position: 'relative' }}>
                    <button className="btn-icon" style={{ width: 28, height: 28 }}
                      onClick={(e) => { e.stopPropagation(); setMenuOpen(menuOpen === s.id ? null : s.id); }}>
                      <FiMoreVertical size={16} color={AppColors.textLight} />
                    </button>
                    {menuOpen === s.id && (
                      <>
                        <div style={{ position: 'fixed', inset: 0, zIndex: 400 }} onClick={(e) => { e.stopPropagation(); setMenuOpen(null); }} />
                        <div className="popup-menu" style={{ zIndex: 500 }}>
                          <button className="popup-menu-item" onClick={(e) => { e.stopPropagation(); setMenuOpen(null); openDialog(s); }}>
                            <FiEdit2 size={16} color="#2196F3" /> Sửa câu này
                          </button>
                          <button className="popup-menu-item danger" onClick={(e) => { e.stopPropagation(); setMenuOpen(null); setDelSentence(s); }}>
                            <FiTrash2 size={16} /> Xóa
                          </button>
                        </div>
                      </>
                    )}
                  </div>
                )}
              </div>
            </motion.div>
          ))}
          </div>
        )}
        </div>
      </div>

      {/* FAB */}
      {isOwner && (
        <motion.button className="fab" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} onClick={() => openDialog()}>
          <FiPlus size={20} />
        </motion.button>
      )}

      {/* Sentence Dialog */}
      <AnimatePresence>
        {showDialog && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowDialog(false)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title">{editSentence ? 'Sửa Câu Nói' : 'Thêm Câu Nói'}</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <textarea className="input-field" placeholder="Tiếng Việt" rows={2} value={vnText} onChange={e => setVnText(e.target.value)} />
                <textarea className="input-field" placeholder="Tiếng Anh (tùy chọn)" rows={2} value={enText} onChange={e => setEnText(e.target.value)} />
              </div>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setShowDialog(false)}>Hủy</button>
                <button className="btn btn-primary" onClick={saveSentence}>Lưu</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Delete Confirm */}
      <AnimatePresence>
        {delSentence && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setDelSentence(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title" style={{ color: AppColors.error }}>Xóa câu này?</h3>
              <p style={{ color: AppColors.textSecondary }}>Bạn có chắc muốn xóa câu nói này không?</p>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setDelSentence(null)}>Hủy</button>
                <button className="btn btn-danger" onClick={handleDelete}>Xóa</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
