import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiArrowLeft, FiPlus, FiEdit2, FiTrash2, FiEye, FiEyeOff, FiMic, FiHeadphones } from 'react-icons/fi';
import { MdAssignment } from 'react-icons/md';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function UserExamManagement() {
  const navigate = useNavigate();
  const uid = auth.currentUser?.uid;
  const [papers, setPapers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showPaperDialog, setShowPaperDialog] = useState(false);
  const [editPaper, setEditPaper] = useState(null);
  const [title, setTitle] = useState('');
  const [duration, setDuration] = useState(30);
  const [saving, setSaving] = useState(false);
  const [selectedPaper, setSelectedPaper] = useState(null);
  const [questions, setQuestions] = useState([]);
  const [showQDialog, setShowQDialog] = useState(false);
  const [editQ, setEditQ] = useState(null);
  const [qType, setQType] = useState('mcq');
  const [qTarget, setQTarget] = useState('');
  const [qOptions, setQOptions] = useState(['', '', '', '']);
  const [qCorrect, setQCorrect] = useState('');
  const [delPaper, setDelPaper] = useState(null);

  useEffect(() => {
    const unsub = FS.myExamPapersStream(uid || '', (snap) => {
      setPapers(FS.parseExamPapers(snap));
      setLoading(false);
    });
    return unsub;
  }, [uid]);

  useEffect(() => {
    if (!selectedPaper) return;
    const unsub = FS.examQuestionsStream(selectedPaper.id, (snap) => {
      setQuestions(FS.parseExamQuestions(snap));
    });
    return unsub;
  }, [selectedPaper]);

  const openPaperDialog = (p = null) => {
    setEditPaper(p);
    setTitle(p?.title || '');
    setDuration(p?.durationMinutes || 30);
    setShowPaperDialog(true);
  };

  const savePaper = async () => {
    if (!title.trim()) return;
    setSaving(true);
    try {
      const user = auth.currentUser;
      if (editPaper) {
        await FS.updateExamPaper(editPaper.id, { title: title.trim(), duration_minutes: Number(duration) });
      } else {
        const userData = await FS.getUserData(uid);
        await FS.createExamPaper({
          title: title.trim(), duration_minutes: Number(duration),
          creatorId: uid, creatorName: userData?.name || user?.displayName || '',
          isPublished: false,
        });
      }
    } catch (e) { console.error(e); }
    setSaving(false);
    setShowPaperDialog(false);
  };

  const deletePaper = async () => {
    if (delPaper) { await FS.deleteExamPaper(delPaper.id); setDelPaper(null); if (selectedPaper?.id === delPaper.id) setSelectedPaper(null); }
  };

  const togglePublish = async (p) => {
    await FS.setExamPaperPublished(p.id, !p.isPublished);
  };

  const openQDialog = (q = null) => {
    setEditQ(q);
    setQType(q?.type || 'mcq');
    setQTarget(q?.targetText || '');
    setQOptions(q?.options || ['', '', '', '']);
    setQCorrect(q?.correctAnswer || '');
    setShowQDialog(true);
  };

  const saveQuestion = async () => {
    if (!qTarget.trim()) return;
    const data = {
      examPaperId: selectedPaper.id,
      type: qType,
      targetText: qTarget.trim(),
      options: qType === 'mcq' ? qOptions.map(o => o.trim()).filter(Boolean) : [],
      correctAnswer: qType === 'mcq' ? qCorrect.trim() : '',
      orderIndex: editQ?.orderIndex ?? questions.length,
    };
    if (editQ) { await FS.updateExamQuestion(editQ.id, data); }
    else { await FS.createExamQuestion(data); }
    setShowQDialog(false);
  };

  // ── Question builder view ──
  if (selectedPaper) {
    return (
      <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
        <div className="gradient-header">
          <button className="back-btn" onClick={() => setSelectedPaper(null)}><FiArrowLeft size={22} /></button>
          <h2>{selectedPaper.title}</h2>
          <div style={{ width: 48 }} />
        </div>
        <div style={{ padding: '8px 16px', background: AppColors.surface, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontSize: 13, color: AppColors.textSecondary }}>{questions.length} câu hỏi</span>
          <button
            onClick={() => togglePublish(selectedPaper)}
            className={`btn ${selectedPaper.isPublished ? 'btn-secondary' : 'btn-primary'}`}
            style={{ padding: '8px 16px', fontSize: 13 }}
          >
            {selectedPaper.isPublished ? <><FiEyeOff size={14} /> Ẩn</> : <><FiEye size={14} /> Xuất bản</>}
          </button>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0', paddingBottom: 80 }}>
          <div className="page-container">
          <div className="content-grid">
          {questions.map((q, i) => (
            <div key={q.id} className="card" style={{ padding: 14, marginBottom: 10, display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 32, height: 32, borderRadius: 8, background: q.type === 'mcq' ? 'rgba(0,180,216,0.1)' : 'rgba(21,101,192,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                {q.type === 'mcq' ? <FiHeadphones size={16} color={AppColors.accent} /> : <FiMic size={16} color={AppColors.primary} />}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{q.targetText}</p>
                <p style={{ fontSize: 12, color: AppColors.textSecondary }}>Câu {i + 1} • {q.type === 'mcq' ? 'Trắc nghiệm' : 'Phát âm'}</p>
              </div>
              <button className="btn-icon" style={{ width: 28, height: 28 }} onClick={() => openQDialog(q)}>
                <FiEdit2 size={14} color="#2196F3" />
              </button>
              <button className="btn-icon" style={{ width: 28, height: 28 }} onClick={() => FS.deleteExamQuestion(q.id)}>
                <FiTrash2 size={14} color={AppColors.error} />
              </button>
            </div>
          ))}
          </div>
          {questions.length === 0 && <div className="empty-state"><p>Chưa có câu hỏi. Bấm + để thêm.</p></div>}
          </div>
        </div>
        <motion.button className="fab" whileTap={{ scale: 0.95 }} onClick={() => openQDialog()}>
          <FiPlus size={20} /> Thêm câu
        </motion.button>

        {/* Question Dialog */}
        <AnimatePresence>
          {showQDialog && (
            <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowQDialog(false)}>
              <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()} style={{ maxHeight: '80vh', overflow: 'auto' }}>
                <h3 className="modal-title">{editQ ? 'Sửa câu hỏi' : 'Thêm câu hỏi'}</h3>
                <div style={{ display: 'flex', gap: 8, marginBottom: 14 }}>
                  <button className={`btn ${qType === 'mcq' ? 'btn-primary' : 'btn-secondary'}`} style={{ flex: 1, padding: 10 }} onClick={() => setQType('mcq')}>Trắc nghiệm</button>
                  <button className={`btn ${qType === 'pronunciation' ? 'btn-primary' : 'btn-secondary'}`} style={{ flex: 1, padding: 10 }} onClick={() => setQType('pronunciation')}>Phát âm</button>
                </div>
                <textarea className="input-field" placeholder="Nội dung câu hỏi (targetText)" rows={2} value={qTarget} onChange={e => setQTarget(e.target.value)} style={{ marginBottom: 12 }} />
                {qType === 'mcq' && (
                  <>
                    {qOptions.map((opt, i) => (
                      <input key={i} className="input-field" placeholder={`Đáp án ${String.fromCharCode(65 + i)}`} value={opt}
                        onChange={e => { const n = [...qOptions]; n[i] = e.target.value; setQOptions(n); }}
                        style={{ marginBottom: 8 }} />
                    ))}
                    <input className="input-field" placeholder="Đáp án đúng" value={qCorrect} onChange={e => setQCorrect(e.target.value)} style={{ marginBottom: 12, borderColor: AppColors.success }} />
                  </>
                )}
                <div className="modal-actions">
                  <button className="btn btn-secondary" onClick={() => setShowQDialog(false)}>Hủy</button>
                  <button className="btn btn-primary" onClick={saveQuestion}>Lưu</button>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  }

  // ── Papers list view ──
  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>Bài thi của tôi</h2>
        <div style={{ width: 48 }} />
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0', paddingBottom: 80 }}>
        <div className="page-container">
        {loading ? <div className="loading-center"><div className="spinner" /></div> : papers.length === 0 ? (
          <div className="empty-state"><div className="empty-state-icon"><MdAssignment size={40} /></div><p>Chưa có bài thi nào.</p></div>
        ) : <div className="content-grid">
          {papers.map((p, i) => (
          <motion.div key={p.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
            className="card" style={{ padding: 16, cursor: 'pointer' }} onClick={() => setSelectedPaper(p)}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 48, height: 48, borderRadius: 14, background: 'linear-gradient(135deg, #0D47A1, #1976D2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <MdAssignment size={24} color="white" />
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontWeight: 700 }}>{p.title}</p>
                <p style={{ fontSize: 13, color: AppColors.textSecondary }}>{p.durationMinutes} phút</p>
              </div>
              <span className={`badge ${p.isPublished ? 'badge-success' : 'badge-warning'}`}>{p.isPublished ? 'Đã xuất bản' : 'Nháp'}</span>
              <button className="btn-icon" style={{ width: 28, height: 28 }} onClick={(e) => { e.stopPropagation(); openPaperDialog(p); }}><FiEdit2 size={14} /></button>
              <button className="btn-icon" style={{ width: 28, height: 28 }} onClick={(e) => { e.stopPropagation(); setDelPaper(p); }}><FiTrash2 size={14} color={AppColors.error} /></button>
            </div>
          </motion.div>
          ))}
        </div>}
        </div>
      </div>

      <motion.button className="fab" whileTap={{ scale: 0.95 }} onClick={() => openPaperDialog()}>
        <FiPlus size={20} /> Tạo bài thi
      </motion.button>

      {/* Paper Dialog */}
      <AnimatePresence>
        {showPaperDialog && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowPaperDialog(false)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title">{editPaper ? 'Sửa bài thi' : 'Tạo bài thi mới'}</h3>
              <input className="input-field" placeholder="Tên bài thi" value={title} onChange={e => setTitle(e.target.value)} style={{ marginBottom: 14 }} />
              <input className="input-field" type="number" placeholder="Thời gian (phút)" value={duration} onChange={e => setDuration(e.target.value)} />
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setShowPaperDialog(false)}>Hủy</button>
                <button className="btn btn-primary" onClick={savePaper} disabled={saving}>{saving ? '...' : 'Lưu'}</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Delete confirm */}
      <AnimatePresence>
        {delPaper && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setDelPaper(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title" style={{ color: AppColors.error }}>Xóa bài thi?</h3>
              <p style={{ color: AppColors.textSecondary }}>Toàn bộ câu hỏi cũng sẽ bị xóa.</p>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setDelPaper(null)}>Hủy</button>
                <button className="btn btn-danger" onClick={deletePaper}>Xóa</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
