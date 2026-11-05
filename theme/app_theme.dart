import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color accentOrange = Color(0xFFFF8A34);
  static const Color softOrange = Color(0xFFFFF3EB);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF1E2022);
  static const Color textMuted = Color(0xFF777E90);
  static const Color successGreen = Color(0xFF00C566);
  static const Color dangerRed = Color(0xFFE53935);
  static const Color warningYellow = Color(0xFFFFB800);
  static const Color borderLight = Color(0xFFE6E8EC);
}

class App3DDecorations {
  static BoxDecoration card3D({Color color = Colors.white, double radius = 16}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          offset: const Offset(0, 8),
          blurRadius: 16,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ],
      border: Border.all(color: AppColors.borderLight, width: 1),
    );
  }

  static BoxDecoration button3D({Color color = AppColors.primaryOrange, double radius = 12}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.35),
          offset: const Offset(0, 6),
          blurRadius: 12,
        ),
      ],
    );
  }

  static BoxDecoration billSlip3D() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          offset: const Offset(0, 10),
          blurRadius: 20,
        ),
      ],
      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
    );
  }
}
