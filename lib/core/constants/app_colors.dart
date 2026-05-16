import 'package:flutter/material.dart';

/// Tập trung toàn bộ màu sắc của ứng dụng vào một nơi duy nhất.
class AppColors {
  AppColors._();

  // --- Brand ---
  static const Color primary = Color(0xFF2C3E50);
  static const Color accent = Color(0xFF00B4D8);

  // --- Background ---
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Colors.white;

  // --- Text ---
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textLight = Color(0xFFBDC3C7);

  // --- Semantic ---
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);

  // --- Gradient pairs ---
  static const List<Color> primaryGradient = [primary, Color(0xFF3D566E)];
  static const List<Color> accentGradient = [accent, Color(0xFF0077B6)];
  static const List<Color> successGradient = [Color(0xFF11998e), Color(0xFF38ef7d)];
  static const List<Color> errorGradient = [Color(0xFFcb2d3e), Color(0xFFef473a)];
  static const List<Color> purpleGradient = [Color(0xFF4776E6), Color(0xFF8E54E9)];
}
