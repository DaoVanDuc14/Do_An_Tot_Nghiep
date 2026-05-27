import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiArrowLeft, FiCamera, FiEdit, FiLogOut, FiSave, FiX } from 'react-icons/fi';
import { updateProfile } from 'firebase/auth';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import { useAuth } from '../../../hooks/useAuth';
import * as FS from '../../../services/firestoreService';
import { uploadImage } from '../../../services/storageService';

export default function ProfileScreen() {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [editingName, setEditingName] = useState(false);
  const [name, setName] = useState(user?.displayName || '');
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [showLogout, setShowLogout] = useState(false);
  const fileRef = useRef(null);

  const photoUrl = user?.photoURL;
  const initial = (user?.displayName?.[0] || user?.email?.[0] || 'V').toUpperCase();

  const saveName = async () => {
    if (!name.trim()) return;
    setSaving(true);
    try {
      await updateProfile(auth.currentUser, { displayName: name.trim() });
      await FS.updateUserProfile(user.uid, { name: name.trim() });
    } catch (e) { console.error(e); }
    setSaving(false);
    setEditingName(false);
  };

  const handleAvatarUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const url = await uploadImage(file, 'avatars');
      await updateProfile(auth.currentUser, { photoURL: url });
      await FS.updateUserProfile(user.uid, { photoUrl: url });
      window.location.reload(); // Force refresh to show new avatar
    } catch (e) { console.error(e); }
    setUploading(false);
  };

  const handleLogout = async () => {
    await logout();
    navigate('/');
  };

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>Hồ Sơ Của Tôi</h2>
        <div style={{ width: 48 }} />
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '32px 0', paddingBottom: 80 }}>
        <div className="page-container content-centered">
        {/* Avatar Card */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="card"
          style={{ padding: '32px 24px', textAlign: 'center', marginBottom: 24, boxShadow: '0 10px 30px rgba(21,101,192,0.1)' }}
        >
          <div style={{ position: 'relative', display: 'inline-block' }}>
            <div style={{
              width: 110, height: 110, borderRadius: '50%', overflow: 'hidden',
              background: 'linear-gradient(135deg, #0D47A1, #1976D2)',
              border: '3px solid rgba(66,165,245,0.3)',
              boxShadow: '0 6px 20px rgba(21,101,192,0.25)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {uploading ? (
                <div className="spinner" style={{ borderTopColor: 'white' }} />
              ) : photoUrl ? (
                <img src={photoUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              ) : (
                <span style={{ color: 'white', fontSize: 36, fontWeight: 700 }}>{initial}</span>
              )}
            </div>
            <button
              onClick={() => fileRef.current?.click()}
              style={{
                position: 'absolute', bottom: 0, right: 0,
                width: 36, height: 36, borderRadius: '50%',
                background: 'linear-gradient(135deg, #00B4D8, #0077B6)',
                border: '2.5px solid white', cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: '0 3px 8px rgba(0,180,216,0.35)',
              }}
            >
              <FiCamera size={15} color="white" />
            </button>
            <input ref={fileRef} type="file" accept="image/*" hidden onChange={handleAvatarUpload} />
          </div>

          <h2 style={{ fontSize: 24, fontWeight: 800, marginTop: 20 }}>{user?.displayName || 'Người dùng'}</h2>
          <div style={{
            display: 'inline-block', padding: '5px 14px', borderRadius: 20,
            background: 'rgba(21,101,192,0.08)', marginTop: 6,
          }}>
            <span style={{ color: AppColors.primary, fontSize: 13, fontWeight: 500 }}>{user?.email}</span>
          </div>
        </motion.div>

        {/* Actions Card */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="card"
          style={{ padding: 20 }}
        >
          {/* Edit Name Form */}
          {editingName ? (
            <div style={{ marginBottom: 16 }}>
              <input
                className="input-field"
                placeholder="Tên hiển thị"
                value={name}
                onChange={e => setName(e.target.value)}
                style={{ marginBottom: 14 }}
              />
              <div style={{ display: 'flex', gap: 12 }}>
                <button
                  className="btn btn-secondary"
                  style={{ flex: 1, padding: 14 }}
                  onClick={() => { setEditingName(false); setName(user?.displayName || ''); }}
                  disabled={saving}
                >
                  Hủy
                </button>
                <button
                  className="btn btn-primary"
                  style={{ flex: 1, padding: 14 }}
                  onClick={saveName}
                  disabled={saving}
                >
                  {saving ? <span className="spinner" style={{ width: 18, height: 18, borderWidth: 2 }} /> : <><FiSave size={16} /> Lưu</>}
                </button>
              </div>
              <hr style={{ margin: '16px 0', border: 'none', borderTop: '1px solid #E8EDF5' }} />
            </div>
          ) : (
            <ActionButton
              icon={<FiEdit size={20} />}
              label="Điều chỉnh thông tin"
              onClick={() => setEditingName(true)}
            />
          )}

          {!editingName && <div style={{ height: 12 }} />}

          <ActionButton
            icon={<FiLogOut size={20} />}
            label="Đăng xuất"
            variant="danger"
            onClick={() => setShowLogout(true)}
          />
        </motion.div>
        </div>
      </div>

      {/* Logout Dialog */}
      {showLogout && (
        <div className="modal-overlay" onClick={() => setShowLogout(false)}>
          <motion.div
            className="modal-content"
            initial={{ scale: 0.9 }}
            animate={{ scale: 1 }}
            onClick={e => e.stopPropagation()}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
              <FiLogOut size={22} color={AppColors.error} />
              <h3 style={{ fontWeight: 700 }}>Đăng xuất</h3>
            </div>
            <p style={{ color: AppColors.textSecondary, marginBottom: 20 }}>Bạn có chắc chắn muốn đăng xuất?</p>
            <div className="modal-actions">
              <button className="btn btn-secondary" onClick={() => setShowLogout(false)}>Hủy</button>
              <button className="btn btn-danger" onClick={handleLogout}>Đăng xuất</button>
            </div>
          </motion.div>
        </div>
      )}
    </div>
  );
}

function ActionButton({ icon, label, variant, onClick }) {
  const isDanger = variant === 'danger';
  return (
    <motion.button
      whileHover={{ scale: 1.01, backgroundColor: isDanger ? '#FFF5F5' : '#F0F7FF' }}
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      style={{
        width: '100%', padding: '16px 20px', borderRadius: 14, 
        border: `1px solid ${isDanger ? '#FFCDD2' : '#E3F2FD'}`,
        background: 'white',
        display: 'flex', alignItems: 'center', gap: 16, cursor: 'pointer',
        transition: 'all 0.2s',
      }}
    >
      <div style={{ 
        width: 44, height: 44, borderRadius: 12, 
        background: isDanger ? '#FFEBEE' : '#E3F2FD', 
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: isDanger ? AppColors.error : AppColors.primary
      }}>
        {icon}
      </div>
      <span style={{ flex: 1, fontWeight: 600, fontSize: 16, textAlign: 'left', color: AppColors.textPrimary }}>{label}</span>
      <FiArrowLeft size={20} style={{ transform: 'rotate(180deg)', color: AppColors.textLight }} />
    </motion.button>
  );
}
