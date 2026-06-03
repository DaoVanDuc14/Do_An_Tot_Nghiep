/// Tập trung chuỗi văn bản dùng trong app.
class AppStrings {
  AppStrings._();

  static const String appName = 'VGo';
  // Thay đổi từ link Hugging Face sang HTTP + IP VPS + Port 8000
  static const String apiBase = 'http://116.118.2.137:8000/api/v1';
  static const String evalEndpoint = '$apiBase/evaluate';
  static const String ttsEndpoint = '$apiBase/tts';

  // Auth
  static const String login = 'Đăng Nhập';
  static const String register = 'Đăng Ký';
  static const String logout = 'Đăng xuất';
  static const String welcomeBack = 'Chào mừng trở lại!';
  static const String createAccount = 'Tạo tài khoản mới';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Mật khẩu';
  static const String nameLabel = 'Họ và Tên';
  static const String fillAllFields = 'Vui lòng điền đầy đủ thông tin!';
  static const String wrongCredentials = 'Email hoặc mật khẩu không chính xác!';
  static const String emailInUse = 'Email này đã được đăng ký!';
  static const String weakPassword = 'Mật khẩu phải có ít nhất 6 ký tự!';

  // Online Test
  static const String onlineTestTitle = 'Bài Kiểm Tra';
  static const String pronunciationType = '🎙 Kiểm Tra Phát Âm';
  static const String mcqType = '🎧 Nghe - Chọn Đáp Án';
  static const String accuracy = 'Độ chính xác';
  static const String correctAnswer = '🎉 Chính xác! +10 điểm';
  static const String wrongAnswer = '❌ Chưa đúng, thử lại nào!';

  // Common
  static const String save = 'Lưu';
  static const String cancel = 'Hủy';
  static const String delete = 'Xóa';
  static const String edit = 'Sửa';
  static const String loading = 'Đang tải...';
  static const String errorGeneric = 'Đã xảy ra lỗi, vui lòng thử lại!';
}
