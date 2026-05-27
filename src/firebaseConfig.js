import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: "AIzaSyAFYx84TkM4LDRNO1EXiGHgylsgLmCWkaI",
  authDomain: "vku-vietnamese-learning.firebaseapp.com",
  projectId: "vku-vietnamese-learning",
  storageBucket: "vku-vietnamese-learning.firebasestorage.app",
  messagingSenderId: "291922863219",
  appId: "1:291922863219:web:5eeb7706d4524a7bdff606",
  measurementId: "G-7SJXLJY8NQ",
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export default app;
