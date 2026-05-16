import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/topic.dart';
import '../data/models/sentence.dart';
import '../data/models/online_test.dart';
import '../data/models/exam_paper.dart';
import '../data/models/exam_question.dart';

/// Lớp service tập trung tất cả các thao tác với Firestore.
class FirestoreService {
  FirestoreService._();

  static final _db = FirebaseFirestore.instance;

  // ─── COLLECTIONS ──────────────────────────────────────────
  static const _users = 'users';
  static const _topics = 'topics';
  static const _sentences = 'sentences';
  static const _onlineTests = 'online_tests';
  static const _userProgress = 'user_progress';
  static const _testResults = 'test_results';
  static const _examPapers = 'exam_papers';
  static const _examQuestions = 'exam_questions';

  // ─── USER ─────────────────────────────────────────────────

  /// Lắng nghe realtime document của user theo uid.
  static Stream<DocumentSnapshot> userStream(String uid) =>
      _db.collection(_users).doc(uid).snapshots();

  /// Lấy role của user (trả về 'user' nếu không tìm thấy).
  static Future<String> getUserRole(String uid) async {
    final doc = await _db.collection(_users).doc(uid).get();
    if (!doc.exists) return 'user';
    final data = doc.data();
    if (data == null) return 'user';
    return data['role'] ?? 'user';
  }

  /// Tạo profile user mới khi đăng ký (Email/Password).
  static Future<void> createUserProfile(User user, String name) async {
    await _db.collection(_users).doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'role': 'user',
      'totalScore': 0,
      'photoUrl': '',
      'language': 'vi',
      'createdAt': Timestamp.now(),
    });
  }

  /// Tạo profile nếu chưa tồn tại – dùng cho Google Sign-In lần đầu.
  static Future<void> createUserProfileIfNotExists(User user) async {
    final doc = await _db.collection(_users).doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection(_users).doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? 'Người dùng',
        'email': user.email ?? '',
        'role': 'user',
        'totalScore': 0,
        'photoUrl': user.photoURL ?? '',
        'language': 'vi',
        'createdAt': Timestamp.now(),
      });
    }
  }

  /// Cộng điểm cho user.
  static Future<void> addScore(String uid, int points) async {
    await _db.collection(_users).doc(uid).set({
      'totalScore': FieldValue.increment(points),
    }, SetOptions(merge: true));
  }

  /// Lấy tất cả users (dành cho Admin).
  static Stream<QuerySnapshot> allUsersStream() =>
      _db.collection(_users).orderBy('createdAt', descending: true).snapshots();

  /// Xóa user khỏi Firestore (chỉ document, không xóa Auth account).
  static Future<void> deleteUserDoc(String uid) async {
    await _db.collection(_users).doc(uid).delete();
  }

  /// Admin cập nhật thông tin user (name, role, avatarUrl).
  static Future<void> updateUserByAdmin(String uid, Map<String, dynamic> data) async {
    await _db.collection(_users).doc(uid).update(data);
  }

  /// Lấy thông tin 1 user theo uid.
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection(_users).doc(uid).get();
    return doc.data();
  }

  // ─── TOPIC ────────────────────────────────────────────────

  static Stream<QuerySnapshot> myTopicsStream(String uid) => _db
      .collection(_topics)
      .where('uid', isEqualTo: uid)
      .snapshots();

  static Stream<QuerySnapshot> publicTopicsStream() => _db
      .collection(_topics)
      .where('isPublic', isEqualTo: true)
      .snapshots();

  static Future<void> createTopic(Map<String, dynamic> data) async {
    await _db.collection(_topics).add({...data, 'createdAt': Timestamp.now()});
  }

  static Future<void> updateTopic(String id, Map<String, dynamic> data) async {
    await _db.collection(_topics).doc(id).update(data);
  }

  static Future<void> deleteTopic(String id) async {
    // Xóa toàn bộ sentences bên trong
    final sentences = await _db
        .collection(_sentences)
        .where('topicId', isEqualTo: id)
        .get();
    for (var doc in sentences.docs) {
      await doc.reference.delete();
    }
    await _db.collection(_topics).doc(id).delete();
  }

  // ─── SENTENCE ─────────────────────────────────────────────

  static Stream<QuerySnapshot> sentencesStream(String topicId) => _db
      .collection(_sentences)
      .where('topicId', isEqualTo: topicId)
      .snapshots();

  static Future<void> createSentence(Map<String, dynamic> data) async {
    await _db.collection(_sentences).add(data);
  }

  static Future<void> updateSentence(String id, Map<String, dynamic> data) async {
    await _db.collection(_sentences).doc(id).update(data);
  }

  static Future<void> deleteSentence(String id) async {
    await _db.collection(_sentences).doc(id).delete();
  }

  // ─── USER PROGRESS ────────────────────────────────────────

  static Stream<DocumentSnapshot> progressStream(String uid, String sentenceId) =>
      _db.collection(_userProgress).doc('${uid}_$sentenceId').snapshots();

  static Stream<QuerySnapshot> topicProgressStream(String uid, String topicId) =>
      _db
          .collection(_userProgress)
          .where('uid', isEqualTo: uid)
          .where('topicId', isEqualTo: topicId)
          .snapshots();

  static Future<void> saveProgress({
    required String uid,
    required String sentenceId,
    required String topicId,
    required int score,
  }) async {
    await _db
        .collection(_userProgress)
        .doc('${uid}_$sentenceId')
        .set({
      'uid': uid,
      'sentenceId': sentenceId,
      'topicId': topicId,
      'score': score,
      'lastUpdated': Timestamp.now(),
    });
  }

  // ─── ONLINE TEST ──────────────────────────────────────────

  static Stream<QuerySnapshot> onlineTestsStream() => _db
      .collection(_onlineTests)
      .orderBy('createdAt', descending: true)
      .snapshots();

  static Future<DocumentReference> createOnlineTest(Map<String, dynamic> data) async {
    return await _db.collection(_onlineTests).add({
      ...data,
      'createdAt': Timestamp.now(),
    });
  }

  static Future<void> updateOnlineTest(String id, Map<String, dynamic> data) async {
    await _db.collection(_onlineTests).doc(id).update(data);
  }

  static Future<void> deleteOnlineTest(String id) async {
    await _db.collection(_onlineTests).doc(id).delete();
  }

  /// Lấy tên topic (dùng cho thống kê).
  static Future<String> getTopicTitle(String topicId) async {
    if (topicId.isEmpty) return 'Không có';
    final doc = await _db.collection(_topics).doc(topicId).get();
    if (!doc.exists) return 'Không tìm thấy';
    final data = doc.data();
    if (data == null) return 'Không có tiêu đề';
    return data['title'] ?? 'Không có tiêu đề';
  }

  /// Helper để parse OnlineTest từ snapshot
  static List<OnlineTest> parseOnlineTests(QuerySnapshot snap) =>
      snap.docs.map((doc) => OnlineTest.fromFirestore(doc)).toList();

  static List<Topic> parseTopics(QuerySnapshot snap) =>
      snap.docs.map((doc) => Topic.fromFirestore(doc)).toList();

  static List<Sentence> parseSentences(QuerySnapshot snap) =>
      snap.docs.map((doc) => Sentence.fromFirestore(doc)).toList();

  // ─── TEST RESULTS ─────────────────────────────────────────

  static Future<void> saveTestResult({
    required String uid,
    required String name,
    required int totalScore,
    required int totalQuestions,
    required int correctAnswers,
    required int timeFinished, // giây
    String testGroupId = 'general',
  }) async {
    final prevQuery = await _db.collection(_testResults)
        .where('userId', isEqualTo: uid)
        .where('testGroupId', isEqualTo: testGroupId)
        .get();
    int prevMax = 0;
    for (var doc in prevQuery.docs) {
      final s = doc.data()['totalScore'] as int? ?? 0;
      if (s > prevMax) prevMax = s;
    }

    await _db.collection(_testResults).add({
      'userId': uid,           // match Firebase: userId
      'name': name,            // extra: dùng cho leaderboard
      'totalScore': totalScore,// match Firebase: totalScore
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'timeFinished': timeFinished, // match Firebase: timeFinished
      'testGroupId': testGroupId,   // match Firebase: testGroupId
      'createdAt': Timestamp.now(), // match Firebase: createdAt
    });
    // Cộng điểm phần chênh lệch (nếu điểm mới cao hơn)
    if (totalScore > prevMax) {
      await addScore(uid, totalScore - prevMax);
    }
  }

  static Stream<QuerySnapshot> leaderboardStream({int limit = 50}) =>
      _db.collection(_users)
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot> myResultsStream(String uid) =>
      _db.collection(_testResults)
          .where('userId', isEqualTo: uid)  // match Firebase: userId
          .orderBy('createdAt', descending: true) // match Firebase: createdAt
          .snapshots();

  // ─── USER PROFILE ─────────────────────────────────────────

  static Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(_users).doc(uid).set(data, SetOptions(merge: true));
  }

  // ─── EXAM PAPERS ──────────────────────────────

  /// Bài thi đã publish (hiển thị cho user làm bài).
  static Stream<QuerySnapshot> examPapersStream() =>
      _db.collection(_examPapers).orderBy('createdAt', descending: true).snapshots();

  /// Tất cả bài thi (cho admin quản lý tổng thể).
  static Stream<QuerySnapshot> allExamPapersStream() =>
      _db.collection(_examPapers).orderBy('createdAt', descending: true).snapshots();

  /// Bài thi của 1 user cụ thể (user quản lý bài của mình).
  static Stream<QuerySnapshot> myExamPapersStream(String uid) => _db
      .collection(_examPapers)
      .where('creatorId', isEqualTo: uid)
      .snapshots();

  static Future<DocumentReference> createExamPaper(Map<String, dynamic> data) async {
    return await _db.collection(_examPapers).add({...data, 'createdAt': Timestamp.now()});
  }

  static Future<void> updateExamPaper(String id, Map<String, dynamic> data) async {
    await _db.collection(_examPapers).doc(id).update(data);
  }

  /// Publish hoặc unpublish bài thi.
  static Future<void> setExamPaperPublished(String id, bool published) async {
    await _db.collection(_examPapers).doc(id).update({'isPublished': published});
  }

  static Future<void> deleteExamPaper(String id) async {
    // Xóa toàn bộ câu hỏi trước
    final qs = await _db.collection(_examQuestions).where('examPaperId', isEqualTo: id).get();
    for (final doc in qs.docs) { await doc.reference.delete(); }
    await _db.collection(_examPapers).doc(id).delete();
  }

  /// Lấy 1 bài thi theo ID (dùng cho deep link).
  static Future<ExamPaper?> getExamPaperById(String id) async {
    final doc = await _db.collection(_examPapers).doc(id).get();
    if (!doc.exists) return null;
    return ExamPaper.fromFirestore(doc);
  }

  static List<ExamPaper> parseExamPapers(QuerySnapshot snap) =>
      snap.docs.map((d) => ExamPaper.fromFirestore(d)).toList();

  // ─── EXAM QUESTIONS ───────────────────────────────────────

  /// Stream câu hỏi theo examPaperId.
  /// Không dùng orderBy('orderIndex') để tránh yêu cầu composite index.
  /// Sort ở client-side trong parseExamQuestions().
  static Stream<QuerySnapshot> examQuestionsStream(String examPaperId) => _db
      .collection(_examQuestions)
      .where('examPaperId', isEqualTo: examPaperId)
      .snapshots();

  static Future<void> createExamQuestion(Map<String, dynamic> data) async {
    await _db.collection(_examQuestions).add(data);
  }

  static Future<void> updateExamQuestion(String id, Map<String, dynamic> data) async {
    await _db.collection(_examQuestions).doc(id).update(data);
  }

  static Future<void> deleteExamQuestion(String id) async {
    await _db.collection(_examQuestions).doc(id).delete();
  }

  /// Parse và sort theo orderIndex ở client-side.
  static List<ExamQuestion> parseExamQuestions(QuerySnapshot snap) {
    final list = snap.docs.map((d) => ExamQuestion.fromFirestore(d)).toList();
    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return list;
  }

  // ─── TEST RESULTS ─────────────────────────────────────────

  /// Lưu kết quả bài thi chi tiết (có answers map).
  static Future<void> saveExamResultDetailed({
    required String userId,
    required String examPaperId,
    required int score,
    required int totalQuestions,
    required Map<String, dynamic> answers,
    required int durationSeconds,
    String? name,
    bool isAutoSubmit = false,
  }) async {
    final prevQuery = await _db.collection(_testResults)
        .where('userId', isEqualTo: userId)
        .where('examPaperId', isEqualTo: examPaperId)
        .get();
    int prevMax = 0;
    for (var doc in prevQuery.docs) {
      final s = doc.data()['score'] as int? ?? 0;
      if (s > prevMax) prevMax = s;
    }

    final now = Timestamp.now();
    await _db.collection(_testResults).add({
      'userId': userId,
      'name': name ?? 'Ẩn danh',
      'examPaperId': examPaperId,
      'score': score,
      'totalScore': score, // Backward compatibility
      'totalQuestions': totalQuestions,
      'answers': answers,
      'durationSeconds': durationSeconds,
      'timeFinished': durationSeconds, // Backward compatibility
      'isAutoSubmit': isAutoSubmit,
      'completedAt': now,
      'createdAt': now, // Backward compatibility
    });
    if (score > prevMax) {
      await addScore(userId, score - prevMax);
    }
  }

  /// Lưu kết quả bài thi đơn giản (backward compat).
  static Future<void> saveExamResult({
    required String userId,
    required String examPaperId,
    required int score,
    required int timeTakenSeconds,
  }) async {
    final prevQuery = await _db.collection(_testResults)
        .where('userId', isEqualTo: userId)
        .where('examPaperId', isEqualTo: examPaperId)
        .get();
    int prevMax = 0;
    for (var doc in prevQuery.docs) {
      final s = doc.data()['score'] as int? ?? 0;
      if (s > prevMax) prevMax = s;
    }

    await _db.collection(_testResults).add({
      'userId': userId,
      'examPaperId': examPaperId,
      'score': score,
      'timeTaken_seconds': timeTakenSeconds,
      'completedAt': Timestamp.now(),
    });
    if (score > prevMax) {
      await addScore(userId, score - prevMax);
    }
  }

  static Stream<QuerySnapshot> myExamResultsStream(String uid) => _db
      .collection(_testResults)
      .where('userId', isEqualTo: uid)
      .orderBy('completedAt', descending: true)
      .snapshots();

  static Stream<QuerySnapshot> examLeaderboardStream(String examPaperId, {int limit = 100}) => _db
      .collection(_testResults)
      .where('examPaperId', isEqualTo: examPaperId)
      .limit(limit)
      .snapshots();
}

