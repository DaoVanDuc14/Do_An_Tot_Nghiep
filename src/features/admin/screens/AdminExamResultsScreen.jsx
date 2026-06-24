import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiArrowLeft, FiClock, FiCalendar, FiMail } from 'react-icons/fi';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function AdminExamResultsScreen() {
  const navigate = useNavigate();
  const { paperId } = useParams();
  const [examTitle, setExamTitle] = useState('');
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(true);

  // Fetch exam paper title
  useEffect(() => {
    (async () => {
      const paper = await FS.getExamPaperById(paperId);
      if (paper) setExamTitle(paper.title);
    })();
  }, [paperId]);

  // Stream results + deduplicate per user (keep highest score)
  useEffect(() => {
    const unsub = FS.examLeaderboardStream(paperId, async (snap) => {
      const allResults = snap.docs.map(d => ({ id: d.id, ...d.data() }));

      // Unique users: keep highest score per userId
      const uniqueMap = {};
      for (const r of allResults) {
        const uid = r.userId || '';
        if (!uid) continue;
        const currentScore = r.score || 0;
        if (!uniqueMap[uid] || currentScore > (uniqueMap[uid].score || 0)) {
          uniqueMap[uid] = r;
        }
      }

      // Sort by score descending
      const sorted = Object.values(uniqueMap);
      sorted.sort((a, b) => (b.score || 0) - (a.score || 0));

      // Fetch user data for each unique user
      const enriched = await Promise.all(
        sorted.map(async (r) => {
          try {
            const userData = await FS.getUserData(r.userId);
            return {
              ...r,
              userName: userData?.name || r.name || 'Người dùng (đã xóa)',
              userEmail: userData?.email || 'Không có email',
            };
          } catch {
            return {
              ...r,
              userName: r.name || 'Người dùng (đã xóa)',
              userEmail: 'Không có email',
            };
          }
        })
      );

      setResults(enriched);
      setLoading(false);
    });
    return unsub;
  }, [paperId]);

  const formatDuration = (seconds) => {
    if (!seconds) return '0 giây';
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return m > 0 ? `${m} phút ${s} giây` : `${s} giây`;
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return 'Không rõ';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    const day = date.getDate();
    const month = date.getMonth() + 1;
    const hours = date.getHours();
    const mins = String(date.getMinutes()).padStart(2, '0');
    return `${day}/${month} ${hours}:${mins}`;
  };

  const getMedalStyle = (index) => {
    if (index === 0) return { background: '#FFD700', color: 'white' }; // Gold
    if (index === 1) return { background: '#B0B0B0', color: 'white' }; // Silver
    if (index === 2) return { background: '#CD7F32', color: 'white' }; // Bronze
    return { background: 'rgba(21,101,192,0.1)', color: AppColors.primary };
  };

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div className="gradient-header" style={{ flexDirection: 'column', alignItems: 'center', padding: '16px 16px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', width: '100%' }}>
          <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
          <div style={{ flex: 1, textAlign: 'center' }}>
            <p style={{ fontSize: 13, opacity: 0.8, color: 'white', margin: 0 }}>Kết quả thi</p>
            <h2 style={{ margin: 0, fontSize: 17, fontWeight: 700, color: 'white', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {examTitle || 'Đang tải...'}
            </h2>
          </div>
          <div style={{ width: 48 }} />
        </div>
      </div>

      {/* Summary bar */}
      {!loading && results.length > 0 && (
        <div style={{
          padding: '12px 16px', width: '100%',
          background: 'rgba(21,101,192,0.08)',
          borderBottom: '1px solid rgba(21,101,192,0.12)',
        }}>
          <p style={{ margin: 0, fontWeight: 700, color: AppColors.primary, fontSize: 14 }}>
            Có {results.length} người dùng đã làm bài thi này
          </p>
        </div>
      )}

      {/* Content */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0' }}>
        <div className="page-container">
          {loading ? (
            <div className="loading-center"><div className="spinner" /></div>
          ) : results.length === 0 ? (
            <div className="empty-state">
              <div className="empty-state-icon">📋</div>
              <p>Chưa có ai hoàn thành bài thi này.</p>
            </div>
          ) : (
            <div className="content-grid">
              {results.map((r, i) => {
                const medalStyle = getMedalStyle(i);
                const timeTaken = r.timeTaken_seconds || r.timeFinished || r.durationSeconds || 0;

                return (
                  <motion.div
                    key={r.id}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: i * 0.03, duration: 0.3 }}
                    className="card"
                    style={{ padding: 16 }}
                  >
                    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
                      {/* Rank badge */}
                      <div style={{
                        width: 36, height: 36, borderRadius: '50%', flexShrink: 0,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontWeight: 700, fontSize: 14,
                        ...medalStyle,
                      }}>
                        {i + 1}
                      </div>

                      {/* User info */}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <p style={{
                          fontWeight: 700, fontSize: 15, color: AppColors.primary,
                          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                          margin: 0,
                        }}>
                          {r.userName}
                        </p>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 2 }}>
                          <FiMail size={12} color={AppColors.textSecondary} />
                          <p style={{
                            fontSize: 12, color: AppColors.textSecondary, margin: 0,
                            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                          }}>
                            {r.userEmail}
                          </p>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 6, flexWrap: 'wrap' }}>
                          <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: AppColors.textSecondary }}>
                            <FiClock size={12} /> {formatDuration(timeTaken)}
                          </span>
                          <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: AppColors.textSecondary }}>
                            <FiCalendar size={12} /> {formatDate(r.completedAt)}
                          </span>
                        </div>
                      </div>

                      {/* Score */}
                      <div style={{ textAlign: 'right', flexShrink: 0 }}>
                        <p style={{ fontSize: 24, fontWeight: 800, color: AppColors.accent, margin: 0, lineHeight: 1 }}>
                          {r.score || 0}
                        </p>
                        <p style={{ fontSize: 11, color: AppColors.textSecondary, margin: 0 }}>điểm</p>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
