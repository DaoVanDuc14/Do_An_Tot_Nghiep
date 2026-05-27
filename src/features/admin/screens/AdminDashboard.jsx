import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiUsers, FiFileText, FiBookOpen, FiLogOut } from 'react-icons/fi';
import { MdAdminPanelSettings } from 'react-icons/md';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import { useAuth } from '../../../hooks/useAuth';
import * as FS from '../../../services/firestoreService';

export default function AdminDashboard() {
  const navigate = useNavigate();
  const { logout } = useAuth();
  const user = auth.currentUser;
  const [stats, setStats] = useState({ topics: 0, exams: 0, users: 0 });

  useEffect(() => {
    const unsub1 = FS.allTopicsStream((snap) => setStats(prev => ({ ...prev, topics: snap.docs.length })));
    const unsub2 = FS.allExamPapersStream((snap) => setStats(prev => ({ ...prev, exams: snap.docs.length })));
    const unsub3 = FS.allUsersStream((snap) => setStats(prev => ({ ...prev, users: snap.docs.length })));
    return () => { unsub1(); unsub2(); unsub3(); };
  }, []);

  const handleLogout = async () => { await logout(); navigate('/'); };

  const menuItems = [
    { icon: <FiUsers size={28} />, title: 'Quản lý Người dùng', desc: 'Xem, sửa, xóa tài khoản', gradient: ['#4776E6', '#8E54E9'], path: '/admin/users' },
    { icon: <FiFileText size={28} />, title: 'Kiểm duyệt Đề Thi', desc: 'Xuất bản, ẩn, xóa đề thi', gradient: ['#00B4D8', '#0077B6'], path: '/admin/exams' },
    { icon: <FiBookOpen size={28} />, title: 'Quản lý Chủ đề', desc: 'Quản lý chủ đề & câu hỏi', gradient: ['#F57C00', '#FFB74D'], path: '/admin/topics' },
  ];

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background }}>
      {/* Banner */}
      <div style={{
        background: 'linear-gradient(135deg, #0D47A1, #1976D2)',
        padding: '32px 20px 40px', borderRadius: '0 0 32px 32px',
        boxShadow: '0 8px 32px rgba(21,101,192,0.2)',
      }}>
        <div style={{ maxWidth: 900, margin: '0 auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ width: 56, height: 56, borderRadius: 16, background: 'rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <MdAdminPanelSettings size={32} color="white" />
            </div>
            <div>
              <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 14 }}>Xin chào Quản trị viên</p>
              <p style={{ color: 'white', fontWeight: 800, fontSize: 18 }}>{user?.email}</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            style={{ background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: 12, padding: '12px 20px', color: 'white', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600, fontSize: 14 }}
          >
            <FiLogOut size={18} /> Đăng xuất
          </button>
        </div>

        {/* Stats */}
        <div className="stats-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 20 }}>
          {[
            { label: 'Chủ đề', value: stats.topics, icon: '📚' },
            { label: 'Đề Thi', value: stats.exams, icon: '📝' },
            { label: 'Người dùng', value: stats.users, icon: '👥' },
          ].map((s, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 + i * 0.1 }}
              style={{
                flex: 1, padding: '24px 16px', borderRadius: 20,
                background: 'rgba(255,255,255,0.12)',
                backdropFilter: 'blur(10px)',
                textAlign: 'center', border: '1px solid rgba(255,255,255,0.1)'
              }}
            >
              <span style={{ fontSize: 32 }}>{s.icon}</span>
              <p style={{ color: 'white', fontWeight: 900, fontSize: 28, marginTop: 8 }}>{s.value}</p>
              <p style={{ color: 'rgba(255,255,255,0.75)', fontSize: 14, fontWeight: 500, marginTop: 4 }}>{s.label}</p>
            </motion.div>
          ))}
        </div>
        </div>
      </div>

      {/* Menu */}
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 20px 80px', width: '100%' }}>
        <h3 style={{ marginBottom: 20, color: AppColors.textPrimary, fontSize: 20, fontWeight: 800 }}>Quản lý hệ thống</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: 20 }}>
        {menuItems.map((item, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + i * 0.1 }}
            whileHover={{ scale: 1.02, translateY: -4 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => navigate(item.path)}
            style={{
              padding: 24, borderRadius: 24, cursor: 'pointer',
              background: `linear-gradient(135deg, ${item.gradient[0]}, ${item.gradient[1]})`,
              boxShadow: `0 10px 24px ${item.gradient[0]}40`,
              display: 'flex', flexDirection: 'column', gap: 16, color: 'white',
              position: 'relative', overflow: 'hidden'
            }}
          >
            {/* Decorative background shape */}
            <div style={{ position: 'absolute', right: -20, top: -20, width: 100, height: 100, borderRadius: '50%', background: 'rgba(255,255,255,0.1)' }} />
            
            <div style={{ width: 56, height: 56, borderRadius: 16, background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {item.icon}
            </div>
            <div>
              <p style={{ fontWeight: 800, fontSize: 18, marginBottom: 4 }}>{item.title}</p>
              <p style={{ fontSize: 14, opacity: 0.85, lineHeight: 1.4 }}>{item.desc}</p>
            </div>
          </motion.div>
        ))}
        </div>
      </div>
    </div>
  );
}
