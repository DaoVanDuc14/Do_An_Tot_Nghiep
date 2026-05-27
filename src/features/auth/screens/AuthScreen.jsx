import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { FiMail, FiLock, FiUser, FiEye, FiEyeOff } from 'react-icons/fi';
import { FcGoogle } from 'react-icons/fc';
import { useAuth } from '../../../hooks/useAuth';
import { AppColors } from '../../../core/constants/appColors';
import './AuthScreen.css';

export default function AuthScreen() {
  const { login, register, loginWithGoogle, resetPassword } = useAuth();
  const [isLogin, setIsLogin] = useState(true);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showForgot, setShowForgot] = useState(false);
  const [forgotEmail, setForgotEmail] = useState('');
  const [forgotMsg, setForgotMsg] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (!email || !password || (!isLogin && !name)) {
      setError('Vui lòng điền đầy đủ thông tin!');
      return;
    }
    setLoading(true);
    try {
      if (isLogin) {
        await login(email, password);
      } else {
        await register(name, email, password);
      }
    } catch (err) {
      const code = err.code || '';
      if (code.includes('user-not-found') || code.includes('wrong-password') || code.includes('invalid-credential')) {
        setError('Email hoặc mật khẩu không chính xác!');
      } else if (code.includes('email-already-in-use')) {
        setError('Email này đã được đăng ký!');
      } else if (code.includes('weak-password')) {
        setError('Mật khẩu phải có ít nhất 6 ký tự!');
      } else {
        setError(err.message || 'Đã xảy ra lỗi!');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleGoogle = async () => {
    setError('');
    setLoading(true);
    try {
      await loginWithGoogle();
    } catch (err) {
      setError(err.message || 'Lỗi đăng nhập Google');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async () => {
    if (!forgotEmail) {
      setForgotMsg('Vui lòng nhập email!');
      return;
    }
    try {
      await resetPassword(forgotEmail);
      setForgotMsg('✅ Đã gửi email đặt lại mật khẩu!');
    } catch {
      setForgotMsg('❌ Không thể gửi email. Kiểm tra lại địa chỉ.');
    }
  };

  return (
    <div className="auth-screen">
      {/* Background gradient */}
      <div className="auth-bg" />

      <motion.div
        className="auth-container"
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: 'easeOut' }}
      >
        {/* Logo */}
        <motion.div
          className="auth-logo"
          initial={{ scale: 0.5, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ duration: 0.5, type: 'spring' }}
        >
          <img src="/images/Logo.png" alt="VGo" />
        </motion.div>

        <h1 className="auth-title">
          {isLogin ? 'Chào mừng trở lại!' : 'Tạo tài khoản mới'}
        </h1>
        <p className="auth-subtitle">
          {isLogin ? 'Đăng nhập để tiếp tục học' : 'Đăng ký để bắt đầu hành trình'}
        </p>

        {/* Form */}
        <form onSubmit={handleSubmit} className="auth-form">
          <AnimatePresence mode="wait">
            {!isLogin && (
              <motion.div
                key="name"
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="input-wrapper"
              >
                <FiUser className="input-icon" />
                <input
                  type="text"
                  placeholder="Họ và Tên"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="auth-input"
                />
              </motion.div>
            )}
          </AnimatePresence>

          <div className="input-wrapper">
            <FiMail className="input-icon" />
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="auth-input"
            />
          </div>

          <div className="input-wrapper">
            <FiLock className="input-icon" />
            <input
              type={showPwd ? 'text' : 'password'}
              placeholder="Mật khẩu"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="auth-input"
            />
            <button
              type="button"
              className="pwd-toggle"
              onClick={() => setShowPwd(!showPwd)}
            >
              {showPwd ? <FiEyeOff /> : <FiEye />}
            </button>
          </div>

          {error && (
            <motion.p
              className="auth-error"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
            >
              {error}
            </motion.p>
          )}

          {isLogin && (
            <button
              type="button"
              className="forgot-btn"
              onClick={() => setShowForgot(true)}
            >
              Quên mật khẩu?
            </button>
          )}

          <button
            type="submit"
            className="btn btn-primary auth-submit"
            disabled={loading}
          >
            {loading ? (
              <span className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} />
            ) : (
              isLogin ? 'Đăng Nhập' : 'Đăng Ký'
            )}
          </button>
        </form>

        {/* Divider */}
        <div className="auth-divider">
          <span>Hoặc đăng nhập với</span>
        </div>

        {/* Google */}
        <button className="google-btn" onClick={handleGoogle} disabled={loading}>
          <FcGoogle size={22} />
          <span>Google</span>
        </button>

        {/* Toggle */}
        <p className="auth-toggle">
          {isLogin ? 'Chưa có tài khoản? ' : 'Đã có tài khoản? '}
          <button
            type="button"
            onClick={() => { setIsLogin(!isLogin); setError(''); }}
          >
            {isLogin ? 'Đăng ký ngay' : 'Đăng nhập'}
          </button>
        </p>
      </motion.div>

      {/* Forgot Password Modal */}
      <AnimatePresence>
        {showForgot && (
          <motion.div
            className="modal-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => { setShowForgot(false); setForgotMsg(''); }}
          >
            <motion.div
              className="modal-content"
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
            >
              <h3 className="modal-title">Đặt lại mật khẩu</h3>
              <p style={{ color: AppColors.textSecondary, marginBottom: 16, fontSize: '0.875rem' }}>
                Nhập email để nhận link đặt lại mật khẩu
              </p>
              <input
                type="email"
                className="input-field"
                placeholder="Email"
                value={forgotEmail}
                onChange={(e) => setForgotEmail(e.target.value)}
              />
              {forgotMsg && (
                <p style={{ marginTop: 12, fontSize: '0.875rem', color: forgotMsg.includes('✅') ? AppColors.success : AppColors.error }}>
                  {forgotMsg}
                </p>
              )}
              <div className="modal-actions">
                <button className="btn btn-secondary" onClick={() => { setShowForgot(false); setForgotMsg(''); }}>
                  Hủy
                </button>
                <button className="btn btn-primary" onClick={handleForgotPassword}>
                  Gửi
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
