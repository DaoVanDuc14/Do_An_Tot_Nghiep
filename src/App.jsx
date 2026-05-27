import { useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './hooks/useAuth';

// Screens
import SplashScreen from './features/shared/screens/SplashScreen';
import AuthScreen from './features/auth/screens/AuthScreen';
import VerifyEmailScreen from './features/auth/screens/VerifyEmailScreen';
import HomeScreen from './features/user/screens/HomeScreen';
import TopicDetailScreen from './features/user/screens/TopicDetailScreen';
import PracticeScreen from './features/user/screens/PracticeScreen';
import NewExamScreen from './features/user/screens/NewExamScreen';
import NewExamResultScreen from './features/user/screens/NewExamResultScreen';
import LeaderboardScreen from './features/user/screens/LeaderboardScreen';
import ProfileScreen from './features/user/screens/ProfileScreen';
import UserExamManagement from './features/user/screens/UserExamManagement';
import AdminDashboard from './features/admin/screens/AdminDashboard';
import AdminUserManagement from './features/admin/screens/AdminUserManagement';
import AdminExamManagement from './features/admin/screens/AdminExamManagement';
import AdminTopicManagement from './features/admin/screens/AdminTopicManagement';

import './index.css';

// ── Protected Route ──
function ProtectedRoute({ children, requireAdmin = false }) {
  const { user, role, loading } = useAuth();

  if (loading) {
    return (
      <div className="loading-center" style={{ minHeight: '100vh' }}>
        <div className="spinner" />
      </div>
    );
  }

  if (!user) return <Navigate to="/" replace />;

  // Email verification check (skip for admin)
  if (!user.emailVerified && role !== 'admin') {
    return <Navigate to="/verify-email" replace />;
  }

  if (requireAdmin && role !== 'admin') {
    return <Navigate to="/home" replace />;
  }

  return children;
}

// ── Auth Wrapper (handles initial routing) ──
function AuthWrapper() {
  const { user, role, loading } = useAuth();

  if (loading) {
    return (
      <div className="loading-center" style={{ minHeight: '100vh' }}>
        <div className="spinner" />
      </div>
    );
  }

  if (!user) return <AuthScreen />;

  if (!user.emailVerified && role !== 'admin') {
    return <VerifyEmailScreen />;
  }

  if (role === 'admin') return <Navigate to="/admin" replace />;
  return <Navigate to="/home" replace />;
}

// ── App ──
function AppRoutes() {
  const [splashDone, setSplashDone] = useState(false);

  if (!splashDone) {
    return <SplashScreen onComplete={() => setSplashDone(true)} />;
  }

  return (
    <Routes>
      {/* Auth */}
      <Route path="/" element={<AuthWrapper />} />
      <Route path="/auth" element={<AuthScreen />} />
      <Route path="/verify-email" element={<VerifyEmailScreen />} />

      {/* User - Protected */}
      <Route path="/home" element={<ProtectedRoute><HomeScreen /></ProtectedRoute>} />
      <Route path="/topic/:id" element={<ProtectedRoute><TopicDetailScreen /></ProtectedRoute>} />
      <Route path="/practice/:sentenceId" element={<ProtectedRoute><PracticeScreen /></ProtectedRoute>} />
      <Route path="/exam/:paperId" element={<ProtectedRoute><NewExamScreen /></ProtectedRoute>} />
      <Route path="/exam-result" element={<ProtectedRoute><NewExamResultScreen /></ProtectedRoute>} />
      <Route path="/leaderboard" element={<ProtectedRoute><LeaderboardScreen /></ProtectedRoute>} />
      <Route path="/profile" element={<ProtectedRoute><ProfileScreen /></ProtectedRoute>} />
      <Route path="/my-exams" element={<ProtectedRoute><UserExamManagement /></ProtectedRoute>} />

      {/* Admin - Protected */}
      <Route path="/admin" element={<ProtectedRoute requireAdmin><AdminDashboard /></ProtectedRoute>} />
      <Route path="/admin/users" element={<ProtectedRoute requireAdmin><AdminUserManagement /></ProtectedRoute>} />
      <Route path="/admin/exams" element={<ProtectedRoute requireAdmin><AdminExamManagement /></ProtectedRoute>} />
      <Route path="/admin/topics" element={<ProtectedRoute requireAdmin><AdminTopicManagement /></ProtectedRoute>} />

      {/* Fallback */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
