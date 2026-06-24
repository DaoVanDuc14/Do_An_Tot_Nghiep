import {
  collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, addDoc,
  query, where, orderBy, limit, onSnapshot, serverTimestamp, writeBatch
} from 'firebase/firestore';
import { db } from '../firebaseConfig';

// ═══════════════════════════════════════════════
//  USER
// ═══════════════════════════════════════════════

export function userStream(uid, callback) {
  return onSnapshot(doc(db, 'users', uid), callback);
}

export async function getUserRole(uid) {
  const snap = await getDoc(doc(db, 'users', uid));
  if (snap.exists()) return snap.data().role || 'user';
  return 'user';
}

export async function getUserData(uid) {
  const snap = await getDoc(doc(db, 'users', uid));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

export async function createUserProfile(uid, data) {
  await setDoc(doc(db, 'users', uid), {
    uid,
    name: data.name || '',
    email: data.email || '',
    role: 'user',
    photoUrl: '',
    totalScore: 0,
    language: 'vi',
    createdAt: serverTimestamp(),
    ...data,
  });
}

export async function createUserProfileIfNotExists(uid, data) {
  const snap = await getDoc(doc(db, 'users', uid));
  if (!snap.exists()) {
    await createUserProfile(uid, data);
  }
}

export async function updateUserProfile(uid, data) {
  await updateDoc(doc(db, 'users', uid), data);
}

export async function addScore(uid, points) {
  const snap = await getDoc(doc(db, 'users', uid));
  if (snap.exists()) {
    const current = snap.data().totalScore || 0;
    await updateDoc(doc(db, 'users', uid), { totalScore: current + points });
  }
}

export function allUsersStream(callback) {
  return onSnapshot(collection(db, 'users'), callback);
}

export async function deleteUserDoc(uid) {
  await deleteDoc(doc(db, 'users', uid));
}

export async function updateUserByAdmin(uid, data) {
  await updateDoc(doc(db, 'users', uid), data);
}

// ═══════════════════════════════════════════════
//  TOPICS
// ═══════════════════════════════════════════════

export function myTopicsStream(uid, callback) {
  const q = query(collection(db, 'topics'), where('uid', '==', uid));
  return onSnapshot(q, callback);
}

export function publicTopicsStream(callback) {
  const q = query(collection(db, 'topics'), where('isPublic', '==', true));
  return onSnapshot(q, callback);
}

export function allTopicsStream(callback) {
  return onSnapshot(collection(db, 'topics'), callback);
}

export async function createTopic(data) {
  await addDoc(collection(db, 'topics'), {
    ...data,
    createdAt: serverTimestamp(),
  });
}

export async function updateTopic(id, data) {
  await updateDoc(doc(db, 'topics', id), data);
}

export async function deleteTopic(id) {
  // Cascade delete sentences
  const q = query(collection(db, 'sentences'), where('topicId', '==', id));
  const snap = await getDocs(q);
  const batch = writeBatch(db);
  snap.docs.forEach(d => batch.delete(d.ref));
  batch.delete(doc(db, 'topics', id));
  await batch.commit();
}

export function parseTopics(snapshot) {
  return snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
}

export async function getTopicTitle(topicId) {
  if (!topicId) return 'Không có';
  const snap = await getDoc(doc(db, 'topics', topicId));
  if (!snap.exists()) return 'Không tìm thấy';
  return snap.data().title || 'Không có tiêu đề';
}

// ═══════════════════════════════════════════════
//  SENTENCES
// ═══════════════════════════════════════════════

export function sentencesStream(topicId, callback) {
  const q = query(collection(db, 'sentences'), where('topicId', '==', topicId));
  return onSnapshot(q, callback);
}

export async function createSentence(data) {
  await addDoc(collection(db, 'sentences'), data);
}

export async function updateSentence(id, data) {
  await updateDoc(doc(db, 'sentences', id), data);
}

export async function deleteSentence(id) {
  await deleteDoc(doc(db, 'sentences', id));
}

export function parseSentences(snapshot) {
  return snapshot.docs.map(d => {
    const data = d.data();
    return {
      id: d.id,
      ...data,
      vietnamese: data.vietnamese || data.text || '',
    };
  });
}

// ═══════════════════════════════════════════════
//  PROGRESS
// ═══════════════════════════════════════════════

export function progressStream(uid, sentenceId, callback) {
  const docId = `${uid}_${sentenceId}`;
  return onSnapshot(doc(db, 'user_progress', docId), callback);
}

export function topicProgressStream(uid, topicId, callback) {
  const q = query(
    collection(db, 'user_progress'),
    where('uid', '==', uid),
    where('topicId', '==', topicId)
  );
  return onSnapshot(q, callback);
}

export async function saveProgress({ uid, sentenceId, topicId, score }) {
  const docId = `${uid}_${sentenceId}`;
  await setDoc(doc(db, 'user_progress', docId), {
    uid, sentenceId, topicId, score,
    lastUpdated: serverTimestamp(),
  });
}

// ═══════════════════════════════════════════════
//  EXAM PAPERS
// ═══════════════════════════════════════════════

export function examPapersStream(callback) {
  return onSnapshot(collection(db, 'exam_papers'), callback);
}

export function allExamPapersStream(callback) {
  return onSnapshot(collection(db, 'exam_papers'), callback);
}

export function myExamPapersStream(uid, callback) {
  const q = query(collection(db, 'exam_papers'), where('creatorId', '==', uid));
  return onSnapshot(q, callback);
}

export async function createExamPaper(data) {
  const ref = await addDoc(collection(db, 'exam_papers'), {
    ...data,
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

export async function updateExamPaper(id, data) {
  await updateDoc(doc(db, 'exam_papers', id), data);
}

export async function setExamPaperPublished(id, published) {
  await updateDoc(doc(db, 'exam_papers', id), { isPublished: published });
}

export async function deleteExamPaper(id) {
  // Cascade delete questions
  const q = query(collection(db, 'exam_questions'), where('examPaperId', '==', id));
  const snap = await getDocs(q);
  const batch = writeBatch(db);
  snap.docs.forEach(d => batch.delete(d.ref));
  batch.delete(doc(db, 'exam_papers', id));
  await batch.commit();
}

export async function getExamPaperById(id) {
  const snap = await getDoc(doc(db, 'exam_papers', id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

export function parseExamPapers(snapshot) {
  return snapshot.docs.map(d => ({
    id: d.id,
    title: d.data().title || '',
    durationMinutes: d.data().duration_minutes || d.data().durationMinutes || 30,
    creatorId: d.data().creatorId || '',
    creatorName: d.data().creatorName || '',
    isPublished: d.data().isPublished || false,
    createdAt: d.data().createdAt,
  }));
}

// ═══════════════════════════════════════════════
//  EXAM QUESTIONS
// ═══════════════════════════════════════════════

export function examQuestionsStream(examPaperId, callback) {
  const q = query(collection(db, 'exam_questions'), where('examPaperId', '==', examPaperId));
  return onSnapshot(q, callback);
}

export async function getExamQuestions(examPaperId) {
  const q = query(collection(db, 'exam_questions'), where('examPaperId', '==', examPaperId));
  const snap = await getDocs(q);
  return parseExamQuestions(snap);
}

export async function createExamQuestion(data) {
  await addDoc(collection(db, 'exam_questions'), data);
}

export async function updateExamQuestion(id, data) {
  await updateDoc(doc(db, 'exam_questions', id), data);
}

export async function deleteExamQuestion(id) {
  await deleteDoc(doc(db, 'exam_questions', id));
}

export function parseExamQuestions(snapshot) {
  const list = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
  list.sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0));
  return list;
}

// ═══════════════════════════════════════════════
//  TEST RESULTS
// ═══════════════════════════════════════════════

export async function saveTestResult(data) {
  await addDoc(collection(db, 'test_results'), {
    ...data,
    completedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
  });
}

export async function saveExamResultDetailed({
  userId, name, examPaperId, score, totalQuestions, answers, durationSeconds, isAutoSubmit,
}) {
  // Save result
  await saveTestResult({
    userId, name, examPaperId,
    score, totalScore: score,
    totalQuestions,
    answers,
    durationSeconds,
    timeFinished: durationSeconds,
    isAutoSubmit,
  });

  // Add score difference (only if higher than previous best)
  const q = query(
    collection(db, 'test_results'),
    where('userId', '==', userId),
    where('examPaperId', '==', examPaperId),
    orderBy('score', 'desc'),
    limit(1)
  );
  const prevSnap = await getDocs(q);
  let prevBest = 0;
  if (!prevSnap.empty) {
    prevBest = prevSnap.docs[0].data().score || 0;
  }
  const diff = score - prevBest;
  if (diff > 0) {
    await addScore(userId, diff);
  }
}

export function leaderboardStream(limitCount, callback) {
  const q = query(collection(db, 'users'), orderBy('totalScore', 'desc'), limit(limitCount || 100));
  return onSnapshot(q, callback);
}

export function myResultsStream(userId, callback) {
  const q = query(collection(db, 'test_results'), where('userId', '==', userId));
  return onSnapshot(q, callback);
}

export function myExamResultsStream(userId, examPaperId, callback) {
  const q = query(
    collection(db, 'test_results'),
    where('userId', '==', userId),
    where('examPaperId', '==', examPaperId)
  );
  return onSnapshot(q, callback);
}

export function examLeaderboardStream(examPaperId, callback) {
  const q = query(
    collection(db, 'test_results'),
    where('examPaperId', '==', examPaperId),
    orderBy('score', 'desc')
  );
  return onSnapshot(q, callback);
}
