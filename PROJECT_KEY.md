# PROJECT_KEY.md — Tài liệu Dự án Cốt lõi

> **Mục đích:** File này là nguồn tham chiếu duy nhất (Single Source of Truth) cho AI và developer.
> AI **PHẢI** đọc file này ở đầu mỗi phiên làm việc và **TỰ ĐỘNG** cập nhật mục LỊCH SỬ CẬP NHẬT sau mỗi thay đổi.

---

## 1. THÔNG TIN CỐT LÕI

| Mục | Thông tin |
|-----|-----------|
| **Tên dự án** | VKU Vietnamese Learning App |
| **Mô tả** | Ứng dụng học Tiếng Việt dành cho người nước ngoài |
| **Platform** | Flutter (cross-platform: Android, iOS, Web) |
| **Backend** | Firebase (Auth + Firestore + Storage) |
| **Package ID (Android)** | `com.vku.duclab.vku_learning_app` |
| **Firebase Project** | `vku-vietnamese-learning` |
| **Storage Bucket** | `vku-vietnamese-learning.firebasestorage.app` |

---

## 2. CẤU TRÚC DATABASE (Firestore)

### Collection: `users`
```
users/{uid}
  ├── uid        : String   — Firebase Auth UID
  ├── name       : String   — Tên hiển thị
  ├── email      : String   — Email
  ├── role       : String   — 'admin' | 'user'  ← QUAN TRỌNG cho phân quyền
  ├── avatarUrl  : String   — URL ảnh đại diện
  └── createdAt  : Timestamp
```

### Collection: `exam_papers`
```
exam_papers/{id}
  ├── title              : String   — Tiêu đề đề thi
  ├── topicId            : String   — FK → topics.id (có thể rỗng)
  ├── duration_minutes   : int      — Thời gian làm bài (phút)
  └── createdAt          : Timestamp
```

### Collection: `exam_questions`
```
exam_questions/{id}
  ├── examPaperId  : String        — FK → exam_papers.id
  ├── type         : String        — 'mcq' | 'pronunciation'
  ├── audioUrl     : String        — Firebase Storage download URL
  ├── targetText   : String        — Đáp án / văn bản đích
  ├── options      : List<String>  — 4 lựa chọn (chỉ với type='mcq')
  └── orderIndex   : int           — Thứ tự câu hỏi (0-indexed)
```

### Collection: `test_results`
```
test_results/{id}
  ├── userId        : String   — FK → users.uid
  ├── examPaperId   : String   — FK → exam_papers.id
  ├── score         : int      — Điểm số
  ├── totalQuestions: int      — Tổng số câu
  ├── answers       : Map      — {questionId: userAnswer}
  └── completedAt   : Timestamp
```

### Collection: `topics`
```
topics/{id}
  ├── title       : String   — Tiêu đề chủ đề
  ├── description : String   — Mô tả
  ├── imageUrl    : String   — URL ảnh bìa
  ├── uid         : String   — UID người tạo
  ├── authorName  : String   — Tên người tạo
  └── isPublic    : bool     — Công khai hay riêng tư
```

### Collection: `sentences`
```
sentences/{id}
  ├── topicId     : String   — FK → topics.id
  ├── vietnamese  : String   — Câu tiếng Việt
  ├── english     : String   — Bản dịch tiếng Anh
  └── audioUrl    : String   — URL audio phát âm mẫu
```

---

## 3. QUY TẮC LOGIC NỀN TẢNG

### 3.1 Xử lý Audio Upload (CỰC KỲ QUAN TRỌNG)

```dart
// ĐÚNG — Luôn dùng StorageService.uploadAudioForExam()
// Web  : truyền bytes (FilePicker với withData: kIsWeb)
// Mobile: truyền filePath
await StorageService.uploadAudioForExam(
  examId: examPaperId,
  bytes: fileBytes,    // Web: result.files.first.bytes
  filePath: filePath,  // Mobile: result.files.first.path
  fileName: fileName,
);
// SAI: Không dùng path trên Web (path = null trên Web)
// SAI: Không gọi getDownloadURL() trước whenComplete()
```

**Quy tắc bắt buộc:**
- Web: dùng `bytes` từ FilePicker với `withData: kIsWeb`
- Phải dùng `uploadTask.whenComplete()` trước `getDownloadURL()` để tránh object-not-found
- Luôn kiểm tra `snapshot.state == TaskState.success` trước khi lấy URL
- Đường dẫn Storage chuẩn: `test_audios/{examId}/{timestamp}.{ext}`

### 3.2 Chấm điểm Phát âm

```
Độ chính xác >= 80% → ĐẠT (Pass)
Độ chính xác < 80%  → CHƯA ĐẠT (Fail)
```

### 3.3 Phân quyền (AuthWrapper)

```dart
// AuthWrapper PHẢI truy vấn Firestore để lấy role SAU KHI đăng nhập
final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
final role = (data?['role'] as String?) ?? 'user';
// role == 'admin' → AdminDashboard
// role == 'user'  → HomeScreen
// user == null    → AuthScreen
```

### 3.4 State Loading — Chống treo màn hình

```dart
// LUÔN dùng try-catch-finally
try {
  setState(() => _isLoading = true);
} catch (e) {
  // xử lý lỗi
} finally {
  if (mounted) setState(() => _isLoading = false);
}
```

---

## 4. KIẾN TRÚC KỸ THUẬT

### 4.1 Dependencies chính

```
flutter: SDK ^3.7.2
firebase_core: ^4.7.0 | firebase_auth: ^6.4.0
cloud_firestore: ^6.3.0 | firebase_storage: ^13.3.0
google_sign_in: ^6.2.1
file_picker: ^8.1.7 | audioplayers: ^6.6.0 | provider: ^6.1.2
```

### 4.2 Google Sign-In v — Quy tắc bắt buộc

Mobile: dùng GoogleSignIn().signIn() → lấy googleUser.authentication → GoogleAuthProvider.credential(idToken, accessToken)
Web: dùng FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider()) (nếu bạn có web)

### 4.3 SHA-1 — Yêu cầu cho Android Production

google-services.json hiện chỉ có client_type: 3 (Web client).
Để Google Sign-In hoạt động ổn định trên Android thật:
1. Lấy SHA-1: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`
2. Thêm vào Firebase Console → Project Settings → Android app → Add fingerprint
3. Tải lại google-services.json

### 4.4 Cấu trúc thư mục

```
lib/
├── core/constants/ | core/theme/
├── data/models/    — exam_paper.dart, exam_question.dart
├── features/admin/screens/ | features/auth/ | features/user/screens/
├── models/         — topic.dart, sentence.dart
├── services/       — firestore_service.dart, storage_service.dart
├── firebase_options.dart
└── main.dart
```

---

## 5. TRẠNG THÁI HIỆN TẠI

### Đã giải quyết
- Lỗi object-not-found khi upload audio (race condition getDownloadURL)
- Treo màn hình khi upload lỗi (thiếu finally block)
- AuthWrapper fetch role từ Firestore đúng cách

### Còn cần xử lý
- SHA-1 chưa được thêm vào Firebase Console → cần test thực tế trên Android device

---

## 6. GIAO THỨC CẬP NHẬT (Update Protocol)

Sau mỗi lần thực hiện yêu cầu, AI phải:
1. Thực hiện code theo yêu cầu
2. Giải thích những gì đã làm
3. TỰ ĐỘNG thêm một mục vào phần LỊCH SỬ CẬP NHẬT bên dưới

---

## 7. LỊCH SỬ CẬP NHẬT

### [2026-05-01] — Khởi tạo & Sửa lỗi Google Auth + Storage

**Lỗi đã sửa:**
- Sửa lỗi getCredentialAsync (Google Sign-In Android): thêm serverClientId vào initialize(), xóa accessToken không tồn tại trong v7
- Sửa lỗi firebase_storage/object-not-found: dùng whenComplete() trước getDownloadURL()
- Sửa treo màn hình: thêm finally block vào save() function

**Files đã thay đổi:**
- lib/main.dart — thêm serverClientId vào GoogleSignIn.instance.initialize()
- lib/features/auth/auth_screen.dart — sửa mobile path, bỏ accessToken
- lib/services/storage_service.dart — viết lại toàn bộ với whenComplete()
- lib/features/admin/screens/admin_exam_management.dart — sửa save() với try-catch-finally

**Lưu ý kỹ thuật:**
- google_sign_in v6
- Firebase Auth trên Android chỉ cần idToken để xác thực Google account
- putData().whenComplete() trả về TaskSnapshot đã commit hoàn toàn trên server

---

### [2026-05-02] — 4 Tính Năng Mới

**Yêu cầu đã thực hiện:**
1. **User tạo & quản lý bài thi** — User có thể tạo/sửa/xóa bài thi của mình qua `UserExamManagement`. Admin chỉ kiểm duyệt (ẩn/xóa), không tạo.
2. **Quên mật khẩu** — Dialog nhập email + `FirebaseAuth.instance.sendPasswordResetEmail` ở `auth_screen.dart`.
3. **Admin quản lý user nâng cao** — Tìm kiếm theo tên/email + dialog sửa (name, role, avatar preview).
4. **Chia sẻ bài thi bằng URL** — Nút share trong card bài thi, copy link dạng `https://domain/?examId=<id>` vào clipboard.

**Files đã thay đổi:**
- `lib/data/models/exam_paper.dart` — Thêm `creatorId`, `creatorName`, `isHidden`
- `lib/services/firestore_service.dart` — Thêm `myExamPapersStream`, `allExamPapersStream`, `setExamPaperHidden`, `getExamPaperById`, `updateUserByAdmin`, `getUserData`
- `lib/features/auth/auth_screen.dart` — Thêm `_showForgotPassword` + nút "Quên mật khẩu?"
- `lib/features/user/screens/user_exam_management.dart` — **MỚI** — User tạo & quản lý bài thi
- `lib/features/user/screens/home_screen.dart` — Thêm nút chia sẻ + nút "Của tôi" trong tab Kiểm Tra
- `lib/features/admin/screens/admin_exam_management.dart` — **Viết lại** — Admin xem/ẩn/xóa đề thi, có tìm kiếm
- `lib/features/admin/screens/admin_user_management.dart` — **Viết lại** — Tìm kiếm + dialog sửa thông tin
- `lib/features/admin/screens/admin_dashboard.dart` — Cập nhật subtitle menu

**Database schema mới (exam_papers):**
```
exam_papers/{id}
  ├── creatorId    : String — UID người tạo (user hoặc admin)
  ├── creatorName  : String — Tên người tạo
  └── isHidden     : bool   — Admin ẩn bài thi (false = hiển thị)
```

**Firestore Index cần tạo:**
- Collection `exam_papers`: composite index (`creatorId` ASC, `createdAt` DESC)
- Collection `exam_papers`: composite index (`isHidden` ASC, `createdAt` DESC)

**Lưu ý:**
- Chia sẻ URL dùng Clipboard (không dùng Firebase Dynamic Links đã deprecated)
- Link format: `https://vku-vietnamese-learning.web.app/?examId=<id>`
- Admin không còn có thể tạo bài thi — chỉ kiểm duyệt

### [2026-05-10] — Module Bài Thi kiểu Azota + Shared Pronunciation

**Yêu cầu đã thực hiện:**
1. **PronunciationService** — Tách logic gọi API chấm phát âm thành service dùng chung
2. **PronunciationRecorderWidget** — Widget thu âm + chấm điểm dùng chung (Practice + Exam)
3. **ExamPaper model** — Thay `isHidden` → `isPublished`, bỏ `topicId`
4. **ExamQuestion model** — Thay `audioUrl` → `correctAnswer` (cho MCQ), bỏ audio upload hoàn toàn
5. **UI/UX làm bài kiểu Azota** — Top bar (timer+title+submit), bảng số câu (grid), chuyển câu tự do, confirm submit, auto-submit khi hết giờ
6. **Exam Builder** — Tạo câu MCQ có `correctAnswer`, câu pronunciation chỉ `targetText`, publish/draft toggle
7. **Kết quả chi tiết** — Hiển thị từng câu đúng/sai/chưa trả lời, accuracy% cho pronunciation, auto-submit notice
8. **Lưu test_results** — Có `answers` map chi tiết, `totalQuestions`, `isAutoSubmit`, `durationSeconds`

**Files mới:**
- `lib/services/pronunciation_service.dart` — Shared API evaluate + PronunciationResult
- `lib/features/shared/pronunciation_recorder_widget.dart` — Widget thu âm dùng chung

**Files đã thay đổi:**
- `lib/data/models/exam_paper.dart` — `isPublished` thay `isHidden`+`topicId`
- `lib/data/models/exam_question.dart` — `correctAnswer` thay `audioUrl`
- `lib/services/firestore_service.dart` — `setExamPaperPublished()`, `saveExamResultDetailed()`
- `lib/features/user/screens/user_exam_management.dart` — Exam builder + correctAnswer
- `lib/features/user/screens/new_exam_screen.dart` — Azota-style exam taking
- `lib/features/user/screens/new_exam_result_screen.dart` — Chi tiết kết quả
- `lib/features/user/screens/practice_screen.dart` — Dùng shared widget
- `lib/features/user/screens/home_screen.dart` — `isPublished` filter
- `lib/features/admin/screens/admin_exam_management.dart` — Publish/unpublish

**Database schema mới:**
```
exam_papers/{id}
  ├── title, duration_minutes, createdAt
  ├── creatorId, creatorName
  └── isPublished: bool

exam_questions/{id}
  ├── examPaperId, type, targetText, orderIndex
  ├── options: List<String> (MCQ)
  └── correctAnswer: String (MCQ)

test_results/{id}
  ├── userId, examPaperId, score, totalQuestions
  ├── answers: Map<questionId, {type, selected/accuracy, isCorrect}>
  ├── durationSeconds, isAutoSubmit
  └── completedAt
```


### [2026-05-11] — Fix Leaderboard, Online Test Tab, Admin Topics, Remove Dark Mode

**Yêu cầu đã thực hiện:**
1. **Fix Leaderboard:** Đã sửa lỗi query sai collection. Thay vì lấy từ 	est_results, nay đã chuyển sang lấy từ collection users và sắp xếp theo 	otalScore giảm dần. Thêm fallback nếu thiếu avatar, name, uid.
2. **Tab Kiểm Tra:** Sửa lỗi mất giao diện. Đã tách 2 nút "Bảng xếp hạng" và "Bài thi của tôi" thành một row riêng bên trên. Nếu danh sách đề thi trống, header và các nút này vẫn được hiển thị, chỉ list đề thi hiện Empty State.
3. **Admin Module:** Xóa hoàn toàn file dmin_test_management.dart (Kiểm tra bài cũ). Thêm dmin_topic_management.dart và dmin_sentence_management.dart để admin có quyền CRUD Chủ đề bài học và Từ vựng.
4. **Remove Dark Mode:** Đã loại bỏ hoàn toàn chức năng Theme Mode (xoá icon toggle trong app bar của HomeScreen, xoá import và file 	heme_provider.dart, điều chỉnh MaterialApp luôn dùng AppTheme.theme).

**Files đã thay đổi/thêm/xóa:**
- lib/services/firestore_service.dart — Đổi query leaderboardStream sang _users.
- lib/features/user/screens/leaderboard_screen.dart — Cập nhật UI đọc fields từ user document thay vì test_result, xoá logic group by userId cũ.
- lib/features/user/screens/home_screen.dart — Cấu trúc lại _buildOnlineTestTab để không ẩn header khi papers.isEmpty, gỡ bỏ ThemeProvider.
- lib/main.dart — Gỡ bỏ ChangeNotifierProvider của ThemeProvider.
- lib/core/theme/theme_provider.dart — Xóa.
- lib/features/admin/screens/admin_test_management.dart — Xóa.
- lib/features/admin/screens/admin_topic_management.dart — Tạo mới.
- lib/features/admin/screens/admin_sentence_management.dart — Tạo mới.
- lib/features/admin/screens/admin_dashboard.dart — Thay thế routing kiểm tra cũ sang quản lý topics.

**Lưu ý Firestore:**
- Không yêu cầu thêm Composite Index mới, các tính năng sử dụng mặc định single-field index.

---

### [2026-05-12] — Fix Đăng ký "notfound" & Thay bằng Email Verification Link

**Yêu cầu đã thực hiện:**
1. **Fix lỗi "notfound":** Loại bỏ việc gọi Firebase Cloud Function `sendOTP` (do function không tồn tại hoặc lỗi deploy gây ra 404/not-found). Chuyển sang sử dụng trực tiếp `createUserWithEmailAndPassword` từ Firebase Auth client SDK.
2. **Xác minh qua Email Link:** Sử dụng `sendEmailVerification()` thay thế hoàn toàn hệ thống gửi mã OTP. Đã tạo thêm `VerifyEmailScreen` để chặn người dùng đăng nhập khi chưa xác minh email (trừ admin, người dùng Google).
3. **Quên mật khẩu:** App hiện đã sử dụng `sendPasswordResetEmail()` mặc định từ trước (ở hàm `_showForgotPassword` trong `auth_screen.dart`), không sử dụng OTP.
4. **Cập nhật Auth Wrapper:** Chuyển `authStateChanges()` thành `userChanges()` trong `AuthWrapper` để app có thể phản hồi khi thực hiện `user.reload()` (xác minh email).

**Files đã thay đổi/thêm:**
- `lib/features/auth/auth_screen.dart` — Xoá dialog OTP đăng ký, dùng đăng ký trực tiếp và gọi `sendEmailVerification()`.
- `lib/features/auth/auth_wrapper.dart` — Lắng nghe `userChanges()`, kiểm tra `emailVerified`, chặn chuyển hướng vào HomeScreen nếu chưa xác minh.
- `lib/features/auth/verify_email_screen.dart` — Tạo mới màn hình kiểm tra trạng thái xác minh và gửi lại link email.
