import { useState } from 'react';
import { motion } from 'framer-motion';
import { FiMail, FiLogOut, FiRefreshCw } from 'react-icons/fi';
import { useAuth } from '../../../hooks/useAuth';
import { AppColors } from '../../../core/constants/appColors';

export default function VerifyEmailScreen() {
  const { user, resendVerification, reloadUser, logout } = useAuth();
  const [sending, setSending] = useState(false);
  const [checking, setChecking] = useState(false);
  const [msg, setMsg] = useState('');

  const handleResend = async () => {
    setSending(true);
    setMsg('');
    try {
      await resendVerification();
      setMsg('✅ Đã gửi lại email xác minh!');
    } catch {
      setMsg('❌ Không thể gửi email lúc này.');
    } finally {
      setSending(false);
    }
  };

  const handleCheck = async () => {
    setChecking(true);
    setMsg('');
    try {
      await reloadUser();
    } catch {
      setMsg('Lỗi kiểm tra. Thử lại.');
    } finally {
      setChecking(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: `linear-gradient(to bottom, ${AppColors.primaryDark}, ${AppColors.primary}, ${AppColors.background})`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 20,
    }}>
      {/* Logout button */}
      <button
        onClick={logout}
        style={{
          position: 'absolute', top: 16, right: 16,
          background: 'rgba(255,255,255,0.15)', border: 'none',
          color: 'white', borderRadius: 12, padding: '10px 16px',
          cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
          fontWeight: 600, fontSize: '0.875rem',
        }}
      >
        <FiLogOut /> Đăng xuất
      </button>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        style={{
          background: 'white', borderRadius: 24, padding: 36,
          maxWidth: 400, width: '100%', textAlign: 'center',
          boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
        }}
      >
        {/* Animated email icon */}
        <motion.div
          animate={{ scale: [1, 1.1, 1] }}
          transition={{ duration: 2, repeat: Infinity }}
          style={{
            width: 80, height: 80, borderRadius: '50%',
            background: `linear-gradient(135deg, ${AppColors.primaryGradientColors?.[0] || '#0D47A1'}, ${AppColors.primaryGradientColors?.[1] || '#1976D2'})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 24px',
            boxShadow: '0 8px 24px rgba(21,101,192,0.3)',
          }}
        >
          <FiMail size={36} color="white" />
        </motion.div>

        <h2 style={{ color: AppColors.primary, fontWeight: 800, marginBottom: 8 }}>
          Xác minh Email
        </h2>
        <p style={{ color: AppColors.textSecondary, fontSize: '0.875rem', marginBottom: 8 }}>
          Chúng tôi đã gửi email xác minh đến
        </p>
        <p style={{
          color: AppColors.primary, fontWeight: 700, fontSize: '0.9375rem',
          background: 'rgba(21,101,192,0.08)', padding: '8px 16px',
          borderRadius: 12, display: 'inline-block', marginBottom: 24,
        }}>
          {user?.email}
        </p>

        <p style={{ color: AppColors.textSecondary, fontSize: '0.8125rem', marginBottom: 24 }}>
          Hãy kiểm tra hộp thư (và cả thư rác) rồi bấm nút bên dưới
        </p>

        {/* Check button */}
        <button
          onClick={handleCheck}
          disabled={checking}
          className="btn btn-primary"
          style={{ width: '100%', padding: 14, marginBottom: 12, fontSize: '1rem' }}
        >
          {checking ? <span className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} /> : (
            <>
              <FiRefreshCw size={18} />
              Tôi đã xác minh
            </>
          )}
        </button>

        {/* Resend button */}
        <button
          onClick={handleResend}
          disabled={sending}
          className="btn btn-secondary"
          style={{ width: '100%', padding: 12, fontSize: '0.875rem' }}
        >
          {sending ? 'Đang gửi...' : 'Gửi lại email xác minh'}
        </button>

        {msg && (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            style={{
              marginTop: 16, fontSize: '0.875rem',
              color: msg.includes('✅') ? AppColors.success : AppColors.error,
              fontWeight: 600,
            }}
          >
            {msg}
          </motion.p>
        )}
      </motion.div>
    </div>
  );
}
