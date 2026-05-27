import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiSearch, FiPlus, FiX, FiArrowLeft, FiChevronRight, FiMoreVertical, FiEdit2, FiTrash2, FiUser, FiShare2, FiPlay, FiAward, FiFileText, FiClock } from 'react-icons/fi';
import { MdMenuBook, MdSchool, MdAutoStories, MdBookmark, MdLightbulb, MdAssignment, MdLeaderboard, MdEditNote } from 'react-icons/md';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

// ─── Topic Progress Widget ───
function TopicProgress({ topicId }) {
  const [avg, setAvg] = useState(0);
  const uid = auth.currentUser?.uid || '';

  useEffect(() => {
    let unsubS, unsubP;
    let total = 0;
    unsubS = FS.sentencesStream(topicId, (snap) => {
      total = snap.docs.length;
      if (total === 0) { setAvg(0); return; }
      unsubP = FS.topicProgressStream(uid, topicId, (pSnap) => {
        let sum = 0;
        pSnap.docs.forEach(d => { sum += (d.data().score || 0); });
        setAvg(total > 0 ? Math.round(sum / total) : 0);
      });
    });
    return () => { unsubS?.(); unsubP?.(); };
  }, [topicId, uid]);

  return (
    <div style={{ marginTop: 8 }}>
      <div className="progress-bar">
        <div className="progress-bar-fill" style={{ width: `${avg}%` }} />
      </div>
      <p style={{ fontSize: 13, color: AppColors.textSecondary, fontWeight: 600, marginTop: 6 }}>
        {avg}% hoàn thành
      </p>
    </div>
  );
}

// ─── Topic Card ───
const ICONS = [MdMenuBook, MdSchool, MdAutoStories, MdBookmark, MdLightbulb];

function TopicCard({ topic, index, isExplore, isOwner, onEdit, onDelete, onClick }) {
  const [showMenu, setShowMenu] = useState(false);
  const colorIdx = index % 5;
  const Icon = ICONS[colorIdx];
  const gradColors = AppColors.topicGradients[colorIdx];
  const iconColor = AppColors.topicIconColors[colorIdx];

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.04, duration: 0.35 }}
      className="card"
      style={{ padding: 16, cursor: 'pointer', position: 'relative', height: '100%' }}
      onClick={onClick}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14, height: '100%' }}>
        {/* Icon */}
        <div style={{
          width: 56, height: 56, borderRadius: 16, flexShrink: 0,
          background: `linear-gradient(135deg, ${gradColors[0]}, ${gradColors[1]})`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon size={28} color={iconColor} />
        </div>

        {/* Content */}
        <div className="topic-card-content">
          <p style={{ fontSize: 16, fontWeight: 700, color: AppColors.textPrimary }}>{topic.title}</p>
          {topic.description && (
            <p style={{ fontSize: 13, color: AppColors.textSecondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {topic.description}
            </p>
          )}
          {isExplore && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 5 }}>
              <FiUser size={14} color={AppColors.textSecondary} />
              <span style={{ fontSize: 12, color: AppColors.textSecondary, fontStyle: 'italic' }}>{topic.authorName}</span>
            </div>
          )}
          <div className="topic-card-bottom">
            <TopicProgress topicId={topic.id} />
          </div>
        </div>

        {/* Menu / Chevron */}
        {isOwner ? (
          <div style={{ position: 'relative' }}>
            <button
              className="btn-icon"
              onClick={(e) => { e.stopPropagation(); setShowMenu(!showMenu); }}
              style={{ width: 32, height: 32 }}
            >
              <FiMoreVertical color={AppColors.textLight} />
            </button>
            {showMenu && (
              <>
                <div style={{ position: 'fixed', inset: 0, zIndex: 400 }} onClick={(e) => { e.stopPropagation(); setShowMenu(false); }} />
                <div className="popup-menu" style={{ zIndex: 500 }}>
                  <button className="popup-menu-item" onClick={(e) => { e.stopPropagation(); setShowMenu(false); onEdit(); }}>
                    <FiEdit2 size={16} color="#2196F3" /> Sửa
                  </button>
                  <button className="popup-menu-item danger" onClick={(e) => { e.stopPropagation(); setShowMenu(false); onDelete(); }}>
                    <FiTrash2 size={16} /> Xóa
                  </button>
                </div>
              </>
            )}
          </div>
        ) : (
          <FiChevronRight size={24} color={AppColors.textLight} style={{ flexShrink: 0, marginTop: 16 }} />
        )}
      </div>
    </motion.div>
  );
}

// ─── HomeScreen ───
export default function HomeScreen() {
  const navigate = useNavigate();
  const uid = auth.currentUser?.uid;
  const [tab, setTab] = useState(1); // Default "Khám phá"
  const [searching, setSearching] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [myTopics, setMyTopics] = useState([]);
  const [publicTopics, setPublicTopics] = useState([]);
  const [papers, setPapers] = useState([]);
  const [loadingTopics, setLoadingTopics] = useState(true);
  const [loadingPapers, setLoadingPapers] = useState(true);

  // Dialog state
  const [showDialog, setShowDialog] = useState(false);
  const [editTopic, setEditTopic] = useState(null);
  const [dialogTitle, setDialogTitle] = useState('');
  const [dialogDesc, setDialogDesc] = useState('');
  const [dialogPublic, setDialogPublic] = useState(false);
  const [saving, setSaving] = useState(false);

  // Delete confirm
  const [delTopic, setDelTopic] = useState(null);

  useEffect(() => {
    const unsub1 = FS.myTopicsStream(uid || '', (snap) => {
      setMyTopics(FS.parseTopics(snap));
      setLoadingTopics(false);
    });
    const unsub2 = FS.publicTopicsStream((snap) => {
      setPublicTopics(FS.parseTopics(snap));
    });
    const unsub3 = FS.examPapersStream((snap) => {
      const all = FS.parseExamPapers(snap);
      setPapers(all.filter(p => p.isPublished));
      setLoadingPapers(false);
    });
    return () => { unsub1(); unsub2(); unsub3(); };
  }, [uid]);

  const filterTopics = (list) => {
    if (!searchQuery) return list;
    const q = searchQuery.toLowerCase();
    return list.filter(t => t.title.toLowerCase().includes(q) || (t.authorName || '').toLowerCase().includes(q));
  };

  // ── Topic Dialog ──
  const openDialog = (topic = null) => {
    setEditTopic(topic);
    setDialogTitle(topic?.title || '');
    setDialogDesc(topic?.description || '');
    setDialogPublic(topic?.isPublic || false);
    setShowDialog(true);
  };

  const saveTopic = async () => {
    if (!dialogTitle.trim()) return;
    setSaving(true);
    try {
      if (editTopic) {
        await FS.updateTopic(editTopic.id, { title: dialogTitle.trim(), description: dialogDesc.trim(), isPublic: dialogPublic });
      } else {
        const userData = await FS.getUserData(uid);
        await FS.createTopic({
          title: dialogTitle.trim(), description: dialogDesc.trim(),
          imageUrl: '', uid, authorName: userData?.name || 'Ẩn danh', isPublic: dialogPublic,
        });
      }
    } catch (e) { console.error(e); }
    setSaving(false);
    setShowDialog(false);
  };

  const handleDelete = async () => {
    if (delTopic) { await FS.deleteTopic(delTopic.id); setDelTopic(null); }
  };

  const sharePaper = (paper) => {
    const link = `${window.location.origin}/?examId=${paper.id}`;
    navigator.clipboard.writeText(link);
    alert(`🔗 Đã sao chép link: ${paper.title}`);
  };

  const startExam = async (paper) => {
    navigate(`/exam/${paper.id}`);
  };

  // ── Avatar ──
  const user = auth.currentUser;
  const photoUrl = user?.photoURL;
  const initial = (user?.displayName?.[0] || user?.email?.[0] || 'V').toUpperCase();

  // ── Render topic list ──
  const renderTopicList = (topics, isExplore) => {
    const filtered = filterTopics(topics);
    if (loadingTopics) return <div className="loading-center"><div className="spinner" /></div>;
    if (filtered.length === 0) {
      return (
        <div className="empty-state">
          <div className="empty-state-icon">{isExplore ? '🔍' : '📁'}</div>
          <p>{isExplore ? 'Chưa có chủ đề cộng đồng nào.' : 'Bạn chưa tạo chủ đề nào.'}</p>
          {!isExplore && <p className="hint">Bấm nút + để tạo chủ đề mới</p>}
        </div>
      );
    }
    return (
      <div className="page-container" style={{ paddingTop: 20, paddingBottom: 20 }}>
        <div className="content-grid">
          {filtered.map((t, i) => (
            <TopicCard
              key={t.id} topic={t} index={i} isExplore={isExplore}
              isOwner={t.uid === uid}
              onClick={() => navigate(`/topic/${t.id}`, { state: { topic: t } })}
              onEdit={() => openDialog(t)}
              onDelete={() => setDelTopic(t)}
            />
          ))}
        </div>
      </div>
    );
  };

  // ── Render exam tab ──
  const renderExamTab = () => (
    <div className="page-container" style={{ paddingTop: 20, paddingBottom: 20 }}>
      {/* Quick actions */}
      <div style={{ display: 'flex', gap: 14, marginBottom: 24 }}>
        <motion.div
          whileHover={{ scale: 1.02 }}
          onClick={() => navigate('/leaderboard')}
          style={{
            flex: 1, padding: '20px 16px', borderRadius: 16, cursor: 'pointer',
            background: 'linear-gradient(135deg, #FFF3E0, #FFE0B2)',
            boxShadow: '0 3px 8px rgba(255,152,0,0.15)',
            textAlign: 'center',
          }}
        >
          <MdLeaderboard size={36} color="#F57C00" />
          <p style={{ fontWeight: 700, color: '#F57C00', fontSize: 14, marginTop: 8 }}>Bảng xếp hạng</p>
        </motion.div>

        <motion.div
          whileHover={{ scale: 1.02 }}
          onClick={() => navigate('/my-exams')}
          style={{
            flex: 1, padding: '20px 16px', borderRadius: 16, cursor: 'pointer',
            background: `linear-gradient(135deg, rgba(21,101,192,0.08), rgba(66,165,245,0.1))`,
            boxShadow: `0 3px 8px rgba(21,101,192,0.08)`,
            textAlign: 'center',
          }}
        >
          <MdEditNote size={36} color={AppColors.primary} />
          <p style={{ fontWeight: 700, color: AppColors.primary, fontSize: 14, marginTop: 8 }}>Bài thi của tôi</p>
        </motion.div>
      </div>

      {/* System banner */}
      <div style={{
        padding: 20, borderRadius: 20,
        background: 'linear-gradient(135deg, #0D47A1, #1976D2)',
        boxShadow: '0 6px 16px rgba(21,101,192,0.25)',
        display: 'flex', alignItems: 'center', gap: 14, marginBottom: 20, color: 'white',
      }}>
        <div style={{ width: 48, height: 48, borderRadius: 14, background: 'rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <MdAssignment size={28} color="white" />
        </div>
        <div>
          <p style={{ fontSize: 18, fontWeight: 700 }}>Hệ thống Đề Thi</p>
          <p style={{ fontSize: 13, opacity: 0.8 }}>
            {loadingPapers ? 'Đang tải...' : `${papers.length} đề thi đang mở`}
          </p>
        </div>
      </div>

      {/* Papers list */}
      {loadingPapers ? (
        <div className="loading-center"><div className="spinner" /></div>
      ) : papers.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon"><MdAssignment size={40} /></div>
          <p>Chưa có đề thi nào.</p>
          <p className="hint">Admin chưa tạo đề thi nào hoặc chưa xuất bản.</p>
        </div>
      ) : (
        <>
          <p style={{ fontSize: 15, fontWeight: 700, color: AppColors.primary, marginBottom: 12 }}>Chọn đề thi</p>
          <div className="content-grid">
            {papers.map((p, i) => (
              <motion.div
                key={p.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 + i * 0.06 }}
                className="card"
                style={{ padding: 16 }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{
                    width: 48, height: 48, borderRadius: 14, flexShrink: 0,
                    background: 'linear-gradient(135deg, #0D47A1, #1976D2)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <MdAssignment size={26} color="white" />
                  </div>
                  <div style={{ flex: 1 }}>
                    <p style={{ fontSize: 16, fontWeight: 700, color: AppColors.textPrimary }}>{p.title}</p>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <FiClock size={14} color={AppColors.textSecondary} />
                      <span style={{ fontSize: 13, color: AppColors.textSecondary }}>{p.durationMinutes} phút</span>
                      {p.creatorName && (
                        <>
                          <FiUser size={13} color={AppColors.textSecondary} />
                          <span style={{ fontSize: 12, color: AppColors.textSecondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.creatorName}</span>
                        </>
                      )}
                    </div>
                  </div>
                  <button className="btn-icon" onClick={() => sharePaper(p)} title="Chia sẻ">
                    <FiShare2 size={18} color={AppColors.accent} />
                  </button>
                </div>
                <button
                  className="btn btn-primary"
                  style={{ width: '100%', marginTop: 14, padding: 12 }}
                  onClick={() => startExam(p)}
                >
                  <FiPlay size={18} /> Bắt đầu thi
                </button>
              </motion.div>
            ))}
          </div>
        </>
      )}
    </div>
  );

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      {/* ── Top Bar ── */}
      <div style={{ background: AppColors.surface, boxShadow: '0 2px 8px rgba(21,101,192,0.06)' }}>
        <div className="home-header">
          {/* Logo Section */}
          <div className={`home-logo ${searching ? 'mobile-hidden' : ''}`}>
            <img src="/images/logo_khong_nen.png" alt="logo" style={{ width: 60, height: 60, objectFit: 'contain' }} />
            <div style={{ marginLeft: 10 }}>
              <h2 className="logo-text">VGo</h2>
              <p className="slogan-text">Học mọi lúc, vui mọi nơi</p>
            </div>
          </div>

          {/* Search Bar Section */}
          <div className={`home-search ${!searching ? 'mobile-hidden' : ''}`}>
            <button className="btn-icon mobile-only" onClick={() => { setSearching(false); setSearchQuery(''); }}>
              <FiArrowLeft size={20} />
            </button>
            <div className="search-input-wrapper">
              <FiSearch className="search-icon desktop-only" size={18} />
              <input
                className="input-field"
                placeholder="Tìm chủ đề, tác giả..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                autoFocus={searching}
              />
              {searchQuery && (
                <button className="btn-icon clear-btn" onClick={() => setSearchQuery('')}>
                  <FiX size={18} />
                </button>
              )}
            </div>
          </div>

          {/* Actions Section */}
          <div className={`home-actions ${searching ? 'mobile-hidden' : ''}`}>
            <button className="btn-icon mobile-only" onClick={() => setSearching(true)}>
              <FiSearch size={20} />
            </button>
            <div className="avatar" onClick={() => navigate('/profile')}>
              {photoUrl ? <img src={photoUrl} alt="" /> : initial}
            </div>
          </div>
        </div>

        {/* Tab bar */}
        <div className="tab-bar">
          <button className={`tab-item ${tab === 0 ? 'active' : ''}`} onClick={() => setTab(0)}>Cá nhân</button>
          <button className={`tab-item ${tab === 1 ? 'active' : ''}`} onClick={() => setTab(1)}>Khám phá</button>
          <button className={`tab-item ${tab === 2 ? 'active' : ''}`} onClick={() => setTab(2)}>
            <MdAssignment size={18} /> Đề Thi
          </button>
        </div>
      </div>

      {/* ── Tab Content ── */}
      <div style={{ flex: 1, overflowY: 'auto', paddingBottom: 80 }}>
        {tab === 0 && renderTopicList(myTopics, false)}
        {tab === 1 && renderTopicList(publicTopics, true)}
        {tab === 2 && renderExamTab()}
      </div>

      {/* ── FAB ── */}
      {tab !== 2 && (
        <motion.button
          className="fab"
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={() => openDialog()}
        >
          <FiPlus size={20} /> Chủ đề
        </motion.button>
      )}

      {/* ── Topic Dialog ── */}
      <AnimatePresence>
        {showDialog && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => !saving && setShowDialog(false)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title">{editTopic ? 'Sửa Chủ Đề' : 'Thêm Chủ Đề'}</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <input className="input-field" placeholder="Tên chủ đề" value={dialogTitle} onChange={e => setDialogTitle(e.target.value)} />
                <textarea className="input-field" placeholder="Mô tả" rows={2} value={dialogDesc} onChange={e => setDialogDesc(e.target.value)} style={{ resize: 'vertical' }} />
                <div className="toggle-container">
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span>{dialogPublic ? '🌐' : '🔒'}</span>
                    <span style={{ fontWeight: 700 }}>{dialogPublic ? 'Công khai' : 'Cá nhân'}</span>
                  </div>
                  <div className={`toggle ${dialogPublic ? 'active' : ''}`} onClick={() => setDialogPublic(!dialogPublic)} />
                </div>
              </div>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setShowDialog(false)} disabled={saving}>Hủy</button>
                <button className="btn btn-primary" onClick={saveTopic} disabled={saving}>
                  {saving ? <span className="spinner" style={{ width: 18, height: 18, borderWidth: 2 }} /> : 'Lưu'}
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Delete Confirm ── */}
      <AnimatePresence>
        {delTopic && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setDelTopic(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title" style={{ color: AppColors.error }}>Xóa chủ đề?</h3>
              <p style={{ color: AppColors.textSecondary }}>Toàn bộ câu hỏi bên trong cũng sẽ bị xóa vĩnh viễn.</p>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setDelTopic(null)}>Hủy</button>
                <button className="btn btn-danger" onClick={handleDelete}>Xóa</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
