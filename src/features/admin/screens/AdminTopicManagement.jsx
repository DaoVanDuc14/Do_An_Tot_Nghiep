import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiArrowLeft, FiSearch, FiPlus, FiEdit2, FiTrash2 } from 'react-icons/fi';
import { MdMenuBook } from 'react-icons/md';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function AdminTopicManagement() {
  const navigate = useNavigate();
  const [topics, setTopics] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [showDialog, setShowDialog] = useState(false);
  const [editTopic, setEditTopic] = useState(null);
  const [title, setTitle] = useState('');
  const [desc, setDesc] = useState('');
  const [isPublic, setIsPublic] = useState(true);
  const [delTopic, setDelTopic] = useState(null);
  const [selectedTopic, setSelectedTopic] = useState(null);
  const [sentences, setSentences] = useState([]);
  const [showSDialog, setShowSDialog] = useState(false);
  const [editS, setEditS] = useState(null);
  const [vnText, setVnText] = useState('');

  useEffect(() => {
    const unsub = FS.allTopicsStream((snap) => {
      setTopics(FS.parseTopics(snap));
      setLoading(false);
    });
    return unsub;
  }, []);

  useEffect(() => {
    if (!selectedTopic) return;
    const unsub = FS.sentencesStream(selectedTopic.id, (snap) => {
      setSentences(FS.parseSentences(snap));
    });
    return unsub;
  }, [selectedTopic]);

  const filtered = topics.filter(t => t.title.toLowerCase().includes(search.toLowerCase()));

  const openDialog = (t = null) => {
    setEditTopic(t);
    setTitle(t?.title || '');
    setDesc(t?.description || '');
    setIsPublic(t?.isPublic ?? true);
    setShowDialog(true);
  };

  const saveTopic = async () => {
    if (!title.trim()) return;
    if (editTopic) {
      await FS.updateTopic(editTopic.id, { title: title.trim(), description: desc.trim(), isPublic });
    } else {
      await FS.createTopic({ title: title.trim(), description: desc.trim(), imageUrl: '', uid: 'admin', authorName: 'Admin', isPublic });
    }
    setShowDialog(false);
  };

  const deleteTopic = async () => {
    if (delTopic) { await FS.deleteTopic(delTopic.id); setDelTopic(null); }
  };

  const openSDialog = (s = null) => {
    setEditS(s);
    setVnText(s?.vietnamese || '');
    setShowSDialog(true);
  };

  const saveSentence = async () => {
    if (!vnText.trim()) return;
    if (editS) {
      await FS.updateSentence(editS.id, { vietnamese: vnText.trim() });
    } else {
      await FS.createSentence({ vietnamese: vnText.trim(), topicId: selectedTopic.id, audioUrl: '' });
    }
    setShowSDialog(false);
  };

  // ── Sentence management view ──
  if (selectedTopic) {
    return (
      <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
        <div className="gradient-header">
          <button className="back-btn" onClick={() => setSelectedTopic(null)}><FiArrowLeft size={22} /></button>
          <h2>{selectedTopic.title}</h2>
          <div style={{ width: 48 }} />
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0', paddingBottom: 80 }}>
          <div className="page-container">
          {sentences.length === 0 ? (
            <div className="empty-state"><p>Chưa có câu nào. Bấm + để thêm.</p></div>
          ) : <div className="content-grid">
            {sentences.map((s, i) => (
            <div key={s.id} className="card" style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.vietnamese}</p>
              </div>
              <button className="btn-icon" style={{ width: 32, height: 32 }} onClick={() => openSDialog(s)}><FiEdit2 size={15} color="#2196F3" /></button>
              <button className="btn-icon" style={{ width: 32, height: 32 }} onClick={() => FS.deleteSentence(s.id)}><FiTrash2 size={15} color={AppColors.error} /></button>
            </div>
            ))}
          </div>}
          </div>
        </div>
        <motion.button className="fab" whileTap={{ scale: 0.95 }} onClick={() => openSDialog()}>
          <FiPlus size={20} /> Thêm câu
        </motion.button>
        <AnimatePresence>
          {showSDialog && (
            <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowSDialog(false)}>
              <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
                <h3 className="modal-title">{editS ? 'Sửa câu' : 'Thêm câu'}</h3>
                <textarea className="input-field" placeholder="Tiếng Việt" rows={3} value={vnText} onChange={e => setVnText(e.target.value)} style={{ marginBottom: 16 }} />
                <div className="modal-actions">
                  <button className="btn btn-secondary" onClick={() => setShowSDialog(false)}>Hủy</button>
                  <button className="btn btn-primary" onClick={saveSentence}>Lưu</button>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  }

  // ── Topics list ──
  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>Quản lý Chủ đề</h2>
        <div style={{ width: 48 }} />
      </div>
      <div style={{ padding: '12px 16px', background: AppColors.surface }}>
        <div style={{ position: 'relative' }}>
          <FiSearch style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: AppColors.textLight }} />
          <input className="input-field" style={{ paddingLeft: 40 }} placeholder="Tìm chủ đề..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0', paddingBottom: 80 }}>
        <div className="page-container">
        {loading ? <div className="loading-center"><div className="spinner" /></div> : filtered.length === 0 ? (
          <div className="empty-state"><p>Không tìm thấy chủ đề.</p></div>
        ) : <div className="content-grid">
          {filtered.map((t, i) => (
          <motion.div key={t.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.03 }}
            className="card" style={{ padding: 14, cursor: 'pointer' }} onClick={() => setSelectedTopic(t)}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: `linear-gradient(135deg, rgba(245,124,0,0.12), rgba(255,183,77,0.08))`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <MdMenuBook size={22} color="#F57C00" />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</p>
                <p style={{ fontSize: 12, color: AppColors.textSecondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.authorName || 'N/A'} • {t.isPublic ? '🌐 Công khai' : '🔒 Cá nhân'}</p>
              </div>
              <button className="btn-icon" style={{ width: 32, height: 32 }} onClick={(e) => { e.stopPropagation(); openDialog(t); }}><FiEdit2 size={15} color="#2196F3" /></button>
              <button className="btn-icon" style={{ width: 32, height: 32 }} onClick={(e) => { e.stopPropagation(); setDelTopic(t); }}><FiTrash2 size={15} color={AppColors.error} /></button>
            </div>
          </motion.div>
          ))}
        </div>}
        </div>
      </div>

      <motion.button className="fab" whileTap={{ scale: 0.95 }} onClick={() => openDialog()}>
        <FiPlus size={20} /> Thêm
      </motion.button>

      {/* Topic Dialog */}
      <AnimatePresence>
        {showDialog && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowDialog(false)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title">{editTopic ? 'Sửa Chủ Đề' : 'Thêm Chủ Đề'}</h3>
              <input className="input-field" placeholder="Tên chủ đề" value={title} onChange={e => setTitle(e.target.value)} style={{ marginBottom: 12 }} />
              <textarea className="input-field" placeholder="Mô tả" rows={2} value={desc} onChange={e => setDesc(e.target.value)} style={{ marginBottom: 12 }} />
              <div className="toggle-container">
                <span style={{ fontWeight: 600 }}>{isPublic ? '🌐 Công khai' : '🔒 Cá nhân'}</span>
                <div className={`toggle ${isPublic ? 'active' : ''}`} onClick={() => setIsPublic(!isPublic)} />
              </div>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setShowDialog(false)}>Hủy</button>
                <button className="btn btn-primary" onClick={saveTopic}>Lưu</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Delete Dialog */}
      <AnimatePresence>
        {delTopic && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setDelTopic(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title" style={{ color: AppColors.error }}>Xóa chủ đề?</h3>
              <p style={{ color: AppColors.textSecondary }}>Xóa "{delTopic.title}" và toàn bộ câu bên trong?</p>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setDelTopic(null)}>Hủy</button>
                <button className="btn btn-danger" onClick={deleteTopic}>Xóa</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
