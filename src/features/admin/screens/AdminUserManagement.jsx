import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { FiArrowLeft, FiSearch, FiEdit2, FiTrash2, FiX, FiMail } from 'react-icons/fi';
import { sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';

export default function AdminUserManagement() {
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [editUser, setEditUser] = useState(null);
  const [editName, setEditName] = useState('');
  const [editRole, setEditRole] = useState('user');
  const [saving, setSaving] = useState(false);
  const [delUser, setDelUser] = useState(null);

  useEffect(() => {
    const unsub = FS.allUsersStream((snap) => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const filtered = users.filter(u => {
    const q = search.toLowerCase();
    return (u.name || '').toLowerCase().includes(q) || (u.email || '').toLowerCase().includes(q);
  });

  const openEdit = (u) => {
    setEditUser(u);
    setEditName(u.name || '');
    setEditRole(u.role || 'user');
  };

  const saveUser = async () => {
    setSaving(true);
    await FS.updateUserByAdmin(editUser.id, { name: editName.trim(), role: editRole });
    setSaving(false);
    setEditUser(null);
  };

  const sendResetEmail = async (email) => {
    if (!email) return;
    try {
      await sendPasswordResetEmail(auth, email);
      alert(`✅ Đã gửi email đặt lại mật khẩu tới ${email}`);
    } catch (e) {
      alert(`❌ Lỗi gửi email: ${e.message}`);
    }
  };

  const deleteUser = async () => {
    if (delUser) { await FS.deleteUserDoc(delUser.id); setDelUser(null); }
  };

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>Quản lý Người dùng</h2>
        <div style={{ width: 48 }} />
      </div>

      {/* Search */}
      <div style={{ padding: '12px 16px', background: AppColors.surface }}>
        <div style={{ position: 'relative' }}>
          <FiSearch style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: AppColors.textLight }} />
          <input className="input-field" style={{ paddingLeft: 40 }} placeholder="Tìm theo tên hoặc email..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 0' }}>
        <div className="page-container">
        {loading ? <div className="loading-center"><div className="spinner" /></div> : filtered.length === 0 ? (
          <div className="empty-state"><p>Không tìm thấy người dùng.</p></div>
        ) : <div className="content-grid">
          {filtered.map((u, i) => (
            <motion.div key={u.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.03 }}
              className="card" style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
            <div className="avatar" style={{ width: 44, height: 44, fontSize: 16 }}>
              {u.photoUrl ? <img src={u.photoUrl} alt="" /> : (u.name?.[0] || '?').toUpperCase()}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontWeight: 700, fontSize: 15, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.name || 'Chưa đặt tên'}</p>
              <p style={{ fontSize: 12, color: AppColors.textSecondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.email}</p>
            </div>
            <span className={`badge ${u.role === 'admin' ? 'badge-error' : 'badge-primary'}`}>{u.role || 'user'}</span>
            <button className="btn-icon" style={{ width: 32, height: 32 }} onClick={() => openEdit(u)}><FiEdit2 size={15} color="#2196F3" /></button>
            <button className="btn-icon" style={{ width: 32, height: 32 }} onClick={() => setDelUser(u)}><FiTrash2 size={15} color={AppColors.error} /></button>
          </motion.div>
          ))}
        </div>}
        </div>
      </div>

      {/* Edit Dialog */}
      <AnimatePresence>
        {editUser && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setEditUser(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title">Chỉnh sửa người dùng</h3>
              {editUser.photoUrl && (
                <div style={{ textAlign: 'center', marginBottom: 16 }}>
                  <img src={editUser.photoUrl} alt="" style={{ width: 64, height: 64, borderRadius: '50%', objectFit: 'cover' }} />
                </div>
              )}
              <div className="input-group" style={{ marginBottom: 14 }}>
                <label>Tên</label>
                <input className="input-field" value={editName} onChange={e => setEditName(e.target.value)} />
              </div>
              <div className="input-group" style={{ marginBottom: 14 }}>
                <label>Vai trò</label>
                <select className="input-field" value={editRole} onChange={e => setEditRole(e.target.value)}>
                  <option value="user">user</option>
                  <option value="admin">admin</option>
                </select>
              </div>
              {editUser.email && (
                <>
                  <hr style={{ margin: '16px 0', border: 'none', borderTop: '1px solid #E8EDF5' }} />
                  <button
                    className="btn"
                    style={{
                      width: '100%', padding: 12, fontSize: 14, fontWeight: 600,
                      background: 'linear-gradient(135deg, #00B4D8, #0077B6)',
                      color: 'white', border: 'none', borderRadius: 12,
                      cursor: 'pointer', display: 'flex', alignItems: 'center',
                      justifyContent: 'center', gap: 8,
                    }}
                    onClick={() => sendResetEmail(editUser.email)}
                  >
                    <FiMail size={16} /> Gửi Email Đặt Lại Mật Khẩu
                  </button>
                  <p style={{ fontSize: 11, color: AppColors.textSecondary, textAlign: 'center', marginTop: 6 }}>
                    Người dùng sẽ nhận được email có link để tự đổi mật khẩu an toàn.
                  </p>
                </>
              )}
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setEditUser(null)}>Hủy</button>
                <button className="btn btn-primary" onClick={saveUser} disabled={saving}>{saving ? '...' : 'Lưu'}</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Delete Dialog */}
      <AnimatePresence>
        {delUser && (
          <motion.div className="modal-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setDelUser(null)}>
            <motion.div className="modal-content" initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} onClick={e => e.stopPropagation()}>
              <h3 className="modal-title" style={{ color: AppColors.error }}>Xóa người dùng?</h3>
              <p style={{ color: AppColors.textSecondary }}>Xóa tài khoản "{delUser.name || delUser.email}" khỏi hệ thống?</p>
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => setDelUser(null)}>Hủy</button>
                <button className="btn btn-danger" onClick={deleteUser}>Xóa</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
