import { createContext, useContext, useState, useEffect } from 'react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  sendEmailVerification,
  sendPasswordResetEmail,
  signOut,
  updateProfile,
} from 'firebase/auth';
import { auth } from '../firebaseConfig';
import { getUserRole, createUserProfile, createUserProfileIfNotExists } from '../services/firestoreService';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [role, setRole] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        setUser(firebaseUser);
        try {
          const userRole = await getUserRole(firebaseUser.uid);
          setRole(userRole);
        } catch {
          setRole('user');
        }
      } else {
        setUser(null);
        setRole(null);
      }
      setLoading(false);
    });
    return unsub;
  }, []);

  // ── Login ──
  const login = async (email, password) => {
    const cred = await signInWithEmailAndPassword(auth, email, password);
    const userRole = await getUserRole(cred.user.uid);
    setRole(userRole);
    return cred.user;
  };

  // ── Register ──
  const register = async (name, email, password) => {
    const cred = await createUserWithEmailAndPassword(auth, email, password);
    await updateProfile(cred.user, { displayName: name });
    await sendEmailVerification(cred.user);
    await createUserProfile(cred.user.uid, {
      name,
      email,
      role: 'user',
    });
    setRole('user');
    return cred.user;
  };

  // ── Google Sign-In ──
  const loginWithGoogle = async () => {
    const provider = new GoogleAuthProvider();
    const cred = await signInWithPopup(auth, provider);
    await createUserProfileIfNotExists(cred.user.uid, {
      name: cred.user.displayName || '',
      email: cred.user.email || '',
      photoUrl: cred.user.photoURL || '',
    });
    const userRole = await getUserRole(cred.user.uid);
    setRole(userRole);
    return cred.user;
  };

  // ── Forgot Password ──
  const resetPassword = async (email) => {
    await sendPasswordResetEmail(auth, email);
  };

  // ── Verify Email ──
  const resendVerification = async () => {
    if (auth.currentUser) {
      await sendEmailVerification(auth.currentUser);
    }
  };

  const reloadUser = async () => {
    if (auth.currentUser) {
      await auth.currentUser.reload();
      setUser({ ...auth.currentUser });
    }
  };

  // ── Logout ──
  const logout = async () => {
    await signOut(auth);
    setUser(null);
    setRole(null);
  };

  const value = {
    user, role, loading,
    login, register, loginWithGoogle,
    resetPassword, resendVerification, reloadUser,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be inside AuthProvider');
  return ctx;
}
