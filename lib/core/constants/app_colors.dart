import 'package:flutter/material.dart';

/// Tập trung toàn bộ màu sắc của ứng dụng vào một nơi duy nhất.
/// Theme chủ đạo: Xanh dương (Blue) — phù hợp với chủ đề học tập & splash screen.
class AppColors {
  AppColors._();

  // --- Brand - Xanh dương hiện đại ---
  static const Color primary = Color(0xFF1565C0); // Xanh dương đậm chính
  static const Color primaryDark = Color(0xFF0A1628); // Navy đậm (khớp splash)
  static const Color primaryLight = Color(0xFF42A5F5); // Xanh nhạt
  static const Color accent = Color(0xFF00B4D8); // Cyan nhấn

  // --- Background ---
  static const Color background = Color(0xFFF0F6FF); // Xanh cực nhạt
  static const Color surface = Colors.white;

  // --- Text ---
  static const Color textPrimary = Color(0xFF1A2B4A); // Xanh navy đậm cho text
  static const Color textSecondary = Color(0xFF6B7D99); // Xám xanh
  static const Color textLight = Color(0xFFB0BEC5); // Xám nhạt

  // --- Semantic ---
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFD32F2F);

  // --- Gradient pairs ---
  static const List<Color> primaryGradient = [
    Color(0xFF0D47A1),
    Color(0xFF1976D2),
  ];
  static const List<Color> accentGradient = [accent, Color(0xFF0077B6)];
  static const List<Color> splashGradient = [
    Color(0xFF0A1628), // navy đậm ở trên
    Color(0xFF132B4C), // xanh tím giữa
    Color(0xFF1565C0), // xanh dương ở giữa dưới
    Color(0xFF42A5F5), // xanh nhạt gần đáy
    Color(0xFF64B5F6), // xanh rất nhạt ở đáy
  ];
  static const List<Color> headerGradient = [
    Color(0xFF0D47A1),
    Color(0xFF1E88E5),
  ];
  static const List<Color> cardGradient = [
    Color(0xFF1565C0),
    Color(0xFF42A5F5),
  ];
  static const List<Color> successGradient = [
    Color(0xFF1B5E20),
    Color(0xFF4CAF50),
  ];
  static const List<Color> errorGradient = [
    Color(0xFFB71C1C),
    Color(0xFFEF5350),
  ];
  static const List<Color> purpleGradient = [
    Color(0xFF4776E6),
    Color(0xFF8E54E9),
  ];
  static const List<Color> warmGradient = [
    Color(0xFFF57C00),
    Color(0xFFFFB74D),
  ];
}
