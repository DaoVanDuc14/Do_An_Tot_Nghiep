import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiArrowLeft, FiSearch, FiTrash2, FiEye, FiEyeOff, FiClock, FiUser } from 'react-icons/fi';
import { MdAssignment } from 'react-icons/md';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function AdminExamManagement() {
  const navigate = useNavigate();
  const [papers, setPapers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [delPaper, setDelPaper] = useState(null);
  const [viewResults, setViewResults] = useState(null);
  const [results, setResults] = useState([]);

  useEffect(() => {
    const unsub = FS.allExamPapersStream((snap) => {
      setPapers(FS.parseExamPapers(snap));
      setLoading(false);
    });
    return unsub;
  }, []);

  useEffect(() => {
    if (!viewResults) return;
    const unsub = FS.examLeaderboardStream(viewResults.id, (snap) => {
      setResults(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return unsub;
  }, [viewResults]);

  const filtered = papers.filter(p => p.title.toLowerCase().includes(search.toLowerCase()));

  const togglePublish = async (p) => {
    await FS.setExamPaperPublished(p.id, !p.isPublished);
  };

  const deletePaper = async () => {
    if (delPaper) { await FS.deleteExamPaper(delPaper.id); setDelPaper(null); }
  };

  // ── Results view ──
  if (viewResults) {
    return (
      <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
        <div className="gradient-header">
          <button className="back-btn" onClick={() => setViewResults(null)}><FiArrowLeft size={22} /></button>
          <h2>Kết quả: {viewResults.title}</h2>
          <div style={{ width: 48 }} />
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0' }}>
          <div className="page-container">
          {results.length === 0 ? (
            <div className="empty-state"><p>Chưa có kết quả nào.</p></div>
          ) : <div className="content-grid">
            {results.map((r, i) => (
            <div key={r.id} className="card" style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{
                width: 32, height: 32, borderRadius: '50%', flexShrink: 0,
                background: i < 3 ? AppColors.primary : AppColors.background,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: i < 3 ? 'white' : AppColors.textSecondary, fontWeight: 700, fontSize: 13,
              }}>
                {i < 3 ? ['🥇', '🥈', '🥉'][i] : i + 1}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.name || 'Ẩn danh'}</p>
                <p style={{ fontSize: 12, color: AppColors.textSecondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {r.score} điểm • {r.totalQuestions} câu • {Math.floor((r.durationSeconds || 0) / 60)}p{(r.durationSeconds || 0) % 60}s
                </p>
              </div>
              <span style={{ fontSize: 20, fontWeight: 800, color: r.score >= (r.totalQuestions || 1) * 8 ? AppColors.success : AppColors.warning }}>
                {r.score}
              </span>
            </div>
            ))}
          </div>}
          </div>
        </div>
      </div>
    );
  }

  // ── Papers list ──
  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>Kiểm duyệt Đề Thi</h2>
        <div style={{ width: 48 }} />
      </div>

      <div style={{ padding: '12px 16px', background: AppColors.surface }}>
        <div style={{ position: 'relative' }}>
          <FiSearch style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: AppColors.textLight }} />
          <input className="input-field" style={{ paddingLeft: 40 }} placeholder="Tìm đề thi..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0' }}>
        <div className="page-container">
        {loading ? <div className="loading-center"><div className="spinner" /></div> : filtered.length === 0 ? (
          <div className="empty-state"><p>Không có đề thi nào.</p></div>
        ) : <div className="content-grid">
          {filtered.map((p, i) => (
          <motion.div key={p.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.03 }}
            className="card" style={{ padding: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: 'linear-gradient(135deg, #0D47A1, #1976D2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <MdAssignment size={22} color="white" />
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontWeight: 700 }}>{p.title}</p>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 2 }}>
                  <FiClock size={13} color={AppColors.textSecondary} />
                  <span style={{ fontSize: 12, color: AppColors.textSecondary }}>{p.durationMinutes} phút</span>
                  <FiUser size={13} color={AppColors.textSecondary} />
                  <span style={{ fontSize: 12, color: AppColors.textSecondary }}>{p.creatorName}</span>
                </div>
              </div>
              <span className={`badge ${p.isPublished ? 'badge-success' : 'badge-warning'}`}>{p.isPublished ? 'Công khai' : 'Nháp'}</span>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className={`btn ${p.isPublished ? 'btn-secondary' : 'btn-primary'}`} style={{ flex: 1, padding: 10, fontSize: 13 }} onClick={() => togglePublish(p)}>
                {p.isPublished ? <><FiEyeOff size={14} /> Ẩn</> : <><FiEye size={14} /> Xuất bản</>}
              </button>
              <button className="btn btn-secondary" style={{ flex: 1, padding: 10, fontSize: 13 }} onClick={() => setViewResults(p)}>
                📊 Kết quả
              </button>
              <button className="btn btn-danger" style={{ padding: 10, fontSize: 13 }} onClick={() => setDelPaper(p)}>
                <FiTrash2 size={14} />
              </button>
            </div>
          </motion.div>
          ))}
        </div>}
        </div>
      </div>

      <AnimatePresence>
        {delPaper && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setDelPaper(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title" style={{ color: AppColors.error }}>Xóa đề thi?</h3>
              <p style={{ color: AppColors.textSecondary }}>Xóa "{delPaper.title}" và toàn bộ câu hỏi?</p>
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
