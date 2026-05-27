# Chi tiết Toàn bộ Chức năng App: VGo (Học Tiếng Việt AI)

Tài liệu này tổng hợp chi tiết toàn bộ các chức năng của ứng dụng, các file phụ trách chức năng đó và luồng di chuyển (flow) giữa các file trong dự án. Giúp bạn dễ dàng nắm bắt kiến trúc tổng thể.

---

## 1. Luồng Khởi Chạy & Xác Thực (Authentication Flow)

**Chức năng:** Khởi chạy app, kiểm tra trạng thái đăng nhập, phân quyền (User/Admin) và chuyển hướng người dùng đến đúng màn hình mà không bị giật/nháy (flash).

*   **`lib/main.dart`**: Entry point của ứng dụng.
    *   *Luồng (Flow)*: Thiết lập Firebase, hiển thị `SplashScreen` đồng thời với việc pre-fetch (tải trước) dữ liệu xác thực (Auth state) và role (từ Firestore). Sau khi hoàn thành, gọi `AuthWrapper`.
*   **`lib/features/shared/screens/splash_screen.dart`**: Màn hình chờ ban đầu (Logo app).
*   **`lib/features/auth/screens/auth_wrapper.dart`**:
    *   *Chức năng*: Xử lý điều hướng thông minh dựa trên trạng thái (Role).
    *   *Luồng (Flow)*: 
        *   Nếu `user == null` $\rightarrow$ Chuyển đến `AuthScreen`.
        *   Nếu `user` chưa xác thực email (emailVerified == false) $\rightarrow$ Chuyển đến `VerifyEmailScreen`.
        *   Nếu `role == 'admin'` $\rightarrow$ Chuyển đến `AdminDashboard`.
        *   Nếu `role == 'user'` $\rightarrow$ Chuyển đến `HomeScreen`.
*   **`lib/features/auth/screens/auth_screen.dart`**: Màn hình Đăng nhập / Đăng ký (Hỗ trợ Email/Password và Google Sign-In).
*   **`lib/features/auth/screens/verify_email_screen.dart`**: Yêu cầu người dùng bấm vào link xác thực trong email trước khi được vào app.

---

## 2. Hệ Thống Dành Cho Người Dùng (User Mode)

Giao diện chính và các chức năng học tập cốt lõi của học viên.

### 2.1. Trang Chủ (Home & Navigation)
*   **`lib/features/user/screens/home_screen.dart`**: Giao diện chính chứa Bottom/Top Tab với 3 tab:
    *   **Tab "Cá nhân"**: Hiển thị danh sách các chủ đề (Topic) do chính user tạo. Cho phép thêm/sửa/xoá chủ đề.
    *   **Tab "Khám phá"**: Hiển thị danh sách các chủ đề "Công khai" (Public) do tất cả mọi người tạo.
    *   **Tab "Đề Thi"**: Khu vực hiển thị Bảng xếp hạng, Quản lý bài thi cá nhân, và Danh sách các Đề thi đang mở.

### 2.2. Quản Lý Chủ Đề & Học Tập (Topic & Practice)
*   **`lib/features/user/screens/topic_detail_screen.dart`**:
    *   *Chức năng*: Hiển thị chi tiết một chủ đề (bao gồm danh sách các Câu hỏi / Từ vựng).
    *   *Luồng (Flow)*: Từ `home_screen.dart` $\rightarrow$ bấm vào 1 chủ đề $\rightarrow$ mở `topic_detail_screen.dart`.
*   **`lib/features/user/screens/practice_screen.dart`**:
    *   *Chức năng*: Màn hình thực hành/luyện nói. Hiển thị từ/câu cần đọc.
    *   *Luồng (Flow)*: Từ `topic_detail_screen.dart` $\rightarrow$ Bấm nút "Bắt đầu luyện tập" $\rightarrow$ mở `practice_screen.dart`.
*   **`lib/features/shared/pronunciation_recorder_widget.dart`**: Widget được nhúng trong màn hình Practice. Đảm nhiệm việc ghi âm giọng nói của người dùng và gửi đi chấm điểm.
*   **`lib/services/dictionary_service.dart`**: Dịch vụ gọi API từ điển/AI để dịch nghĩa từ, giải thích lỗi sai.

### 2.3. Hệ Thống Thi Thử (Exam System)
*   **`lib/features/user/screens/new_exam_screen.dart`** (và `exam_screen.dart` cũ):
    *   *Chức năng*: Màn hình làm bài thi thực tế. Đếm ngược thời gian, hiển thị câu hỏi, thu âm hoặc chọn đáp án.
    *   *Luồng (Flow)*: Từ tab Đề Thi ở `home_screen.dart` $\rightarrow$ Chọn đề $\rightarrow$ `new_exam_screen.dart`.
*   **`lib/features/user/screens/new_exam_result_screen.dart`** (và `exam_result_screen.dart` cũ):
    *   *Chức năng*: Màn hình hiển thị kết quả sau khi nộp bài (Số câu đúng, điểm số, chi tiết từng câu).
    *   *Luồng (Flow)*: Nộp bài từ `new_exam_screen.dart` $\rightarrow$ `new_exam_result_screen.dart`.
*   **`lib/features/user/screens/user_exam_management.dart`**:
    *   *Chức năng*: Lịch sử làm bài thi của cá nhân user.
*   **`lib/features/user/screens/leaderboard_screen.dart`**:
    *   *Chức năng*: Bảng xếp hạng tổng điểm của người dùng trên toàn hệ thống.

### 2.4. Hồ Sơ Cá Nhân (Profile)
*   **`lib/features/user/screens/profile_screen.dart`**:
    *   *Chức năng*: Hiển thị thông tin user (Avatar, Tên, Điểm). Đổi mật khẩu, đăng xuất.
    *   *Luồng (Flow)*: Từ avatar góc trên bên phải `home_screen.dart` $\rightarrow$ `profile_screen.dart`.

---

## 3. Hệ Thống Dành Cho Quản Trị Viên (Admin Mode)

Khu vực quản lý tổng thể hệ thống, chỉ dành cho tài khoản có `role == 'admin'`.

*   **`lib/features/admin/screens/admin_dashboard.dart`**:
    *   *Chức năng*: Màn hình chính của Admin. Hiển thị thống kê tổng quan (Số lượng User, Topic, Exam).
*   **`lib/features/admin/screens/admin_user_management.dart`**:
    *   *Chức năng*: Xem danh sách người dùng, tìm kiếm, cấp quyền admin hoặc chặn người dùng.
*   **`lib/features/admin/screens/admin_topic_management.dart`**:
    *   *Chức năng*: Quản lý tất cả chủ đề trên hệ thống (Sửa/Xóa mọi chủ đề kể cả của user khác).
*   **`lib/features/admin/screens/admin_sentence_management.dart`**:
    *   *Chức năng*: Quản lý chi tiết các câu hỏi/từ vựng bên trong 1 chủ đề.
*   **`lib/features/admin/screens/admin_exam_management.dart`**:
    *   *Chức năng*: Tạo, sửa, xóa, và "Xuất bản" (Publish) Đề thi.
*   **`lib/features/admin/screens/admin_exam_results_screen.dart`**:
    *   *Chức năng*: Xem chi tiết người dùng nào đã thi được bao nhiêu điểm đối với một đề thi cụ thể.

---

## 4. Các File Dịch Vụ Cốt Lõi (Services)

Các file này không chứa giao diện, mà chứa logic kết nối API, Cơ sở dữ liệu.

*   **`lib/services/firestore_service.dart`**: 
    *   *Chức năng*: Nơi tập trung toàn bộ các hàm gọi Database (Cloud Firestore).
    *   *Nhiệm vụ*: `createUserProfile()`, `getTopics()`, `createExamPaper()`, v.v. Tất cả mọi màn hình cần đọc/ghi dữ liệu đều phải gọi thông qua file này.
*   **`lib/services/pronunciation_service.dart`**:
    *   *Chức năng*: Xử lý file Audio và gọi API AI để chấm điểm phát âm (`AppStrings.evalEndpoint`).
    *   *Nhiệm vụ*: Trả về `accuracy` (độ chính xác), `recognizedText` (chữ nhận diện được) và `passed` (đạt hay không).
*   **`lib/services/dictionary_service.dart`**:
    *   *Chức năng*: Có cơ chế gọi AI model (Gemini/OpenAI/Claude...) để giải thích từ vựng hoặc tạo câu ví dụ. Tự động fallback đổi model nếu bị lỗi mạng hoặc quá tải (dòng 94-114).
*   **`lib/services/storage_service.dart`**:
    *   *Chức năng*: Đẩy file ảnh (Avatar, hình ảnh chủ đề) hoặc file Audio ghi âm lên Firebase Storage.

---

## 5. Dữ Liệu và Models (`lib/data/models`)

Cấu trúc các object dùng trong app để chuẩn hoá dữ liệu trả về từ Firebase.

*   `topic.dart`: Đại diện cho Chủ đề học.
*   `sentence.dart`: Đại diện cho Câu hỏi/Từ vựng trong Practice.
*   `exam_paper.dart`: Đại diện cho một Bài thi.
*   `exam_question.dart`: Đại diện cho các Câu hỏi bên trong bài thi.
*   `online_test.dart` / `quiz.dart`: Các model cũ/tương tự dùng cho chức năng thi.
*   `word_definition.dart`: Model định nghĩa từ vựng trả về từ Dictionary Service.

---

## Tóm Tắt Luồng Di Chuyển Chính:

1. Người dùng mở app $\rightarrow$ `main.dart` $\rightarrow$ `splash_screen.dart` $\rightarrow$ `auth_wrapper.dart`
2. Nếu chưa Login $\rightarrow$ `auth_screen.dart` (Đăng nhập) $\rightarrow$ Vào App.
3. Nếu là User $\rightarrow$ `home_screen.dart`.
   * Muốn học: Chọn Topic $\rightarrow$ `topic_detail_screen.dart` $\rightarrow$ `practice_screen.dart` (Gọi `pronunciation_service.dart` để chấm điểm).
   * Muốn thi: Chọn Tab Đề Thi $\rightarrow$ Chọn Exam $\rightarrow$ `new_exam_screen.dart` $\rightarrow$ Thi xong $\rightarrow$ `new_exam_result_screen.dart` $\rightarrow$ Xem Leaderboard.
4. Nếu là Admin $\rightarrow$ `admin_dashboard.dart`.
   * Muốn quản lý đề thi $\rightarrow$ `admin_exam_management.dart`.
   * Muốn quản lý người dùng $\rightarrow$ `admin_user_management.dart`.
