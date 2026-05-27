import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiArrowLeft } from 'react-icons/fi';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function LeaderboardScreen() {
  const navigate = useNavigate();
  const myUid = auth.currentUser?.uid;
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = FS.leaderboardStream(100, (snap) => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
      setLoading(false);
    });
    return unsub;
  }, []);

  const podiumItem = (user, medal, isLarge) => {
    const name = user?.name || 'Ẩn danh';
    const shortName = name.length > 8 ? name.substring(0, 8) + '...' : name;
    const score = user?.totalScore || 0;
    return (
      <div style={{ textAlign: 'center', flex: 1 }}>
        <span style={{ fontSize: isLarge ? 36 : 28 }}>{medal}</span>
        <p style={{ color: 'white', fontWeight: 700, fontSize: 13, marginTop: 6 }}>{shortName}</p>
        <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 12 }}>{score} đ</p>
      </div>
    );
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', flexDirection: 'column',
      background: `linear-gradient(to bottom, #0D47A1 0%, #1565C0 25%, ${AppColors.background} 50%)`,
    }}>
      {/* AppBar */}
      <div style={{ padding: '12px 8px', display: 'flex', alignItems: 'center' }}>
        <button className="back-btn" onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', color: 'white', cursor: 'pointer', padding: 8 }}>
          <FiArrowLeft size={22} />
        </button>
        <h2 style={{ flex: 1, textAlign: 'center', color: 'white', fontSize: 20, fontWeight: 700 }}>🏆 Bảng Xếp Hạng</h2>
        <div style={{ width: 48 }} />
      </div>

      {loading ? (
        <div className="loading-center"><div className="spinner" style={{ borderTopColor: 'white' }} /></div>
      ) : users.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon" style={{ background: 'rgba(255,255,255,0.1)' }}>🏆</div>
          <p style={{ color: 'rgba(255,255,255,0.7)' }}>Chưa có kết quả nào. Hãy là người đầu tiên!</p>
        </div>
      ) : (
        <>
          {/* Podium */}
          {users.length >= 3 && (
            <div className="page-container">
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              style={{
                margin: '8px 16px', padding: 20, borderRadius: 20,
                background: 'linear-gradient(135deg, rgba(255,255,255,0.12), rgba(255,255,255,0.06))',
                border: '1px solid rgba(255,255,255,0.1)',
                display: 'flex', alignItems: 'flex-end', justifyContent: 'space-evenly',
              }}
            >
              {podiumItem(users[1], '🥈', false)}
              {podiumItem(users[0], '🥇', true)}
              {podiumItem(users[2], '🥉', false)}
            </motion.div>
            </div>
          )}

          {/* List */}
          <div style={{ flex: 1, background: AppColors.background, borderRadius: '24px 24px 0 0', padding: '16px 0', marginTop: 8 }}>
            <div className="page-container">
            {users.map((u, i) => {
              const isMe = u.uid === myUid || u.id === myUid;
              const rankColors = ['#F57C00', '#757575', '#CD7F32'];
              const medals = ['🥇', '🥈', '🥉'];

              return (
                <motion.div
                  key={u.id}
                  initial={{ opacity: 0, x: 10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: i * 0.05 }}
                  style={{
                    padding: 14, marginBottom: 10, borderRadius: 16,
                    background: isMe ? 'rgba(21,101,192,0.06)' : AppColors.surface,
                    border: isMe ? '1.5px solid rgba(21,101,192,0.3)' : '1px solid transparent',
                    boxShadow: '0 3px 8px rgba(21,101,192,0.04)',
                    display: 'flex', alignItems: 'center', gap: 12,
                  }}
                >
                  {/* Rank */}
                  <div style={{
                    width: 36, height: 36, borderRadius: '50%',
                    background: i < 3 ? `linear-gradient(135deg, ${rankColors[i]}60, ${rankColors[i]})` : AppColors.background,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    {i < 3 ? <span style={{ fontSize: 18 }}>{medals[i]}</span> : <span style={{ fontWeight: 700, color: AppColors.textSecondary, fontSize: 13 }}>{i + 1}</span>}
                  </div>

                  {/* Avatar */}
                  <div className="avatar" style={{ width: 40, height: 40 }}>
                    {(u.photoUrl || u.avatarUrl) ? <img src={u.photoUrl || u.avatarUrl} alt="" /> : (u.name?.[0] || '?').toUpperCase()}
                  </div>

                  {/* Name */}
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ fontWeight: 700, fontSize: 15, color: isMe ? AppColors.primary : AppColors.textPrimary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {u.name || 'Ẩn danh'}
                      </span>
                      {isMe && (
                        <span style={{
                          padding: '2px 6px', borderRadius: 6, fontSize: 10, fontWeight: 700,
                          background: 'linear-gradient(135deg, #0D47A1, #1976D2)', color: 'white',
                        }}>Bạn</span>
                      )}
                    </div>
                  </div>

                  {/* Score */}
                  <span style={{ fontSize: 22, fontWeight: 800, color: i < 3 ? rankColors[i] : AppColors.primary }}>
                    {u.totalScore || 0}
                  </span>
                  <span style={{ fontSize: 12, color: AppColors.textSecondary }}> đ</span>
                </motion.div>
              );
            })}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
