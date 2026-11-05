import 'package:flutter/material.dart';

class Theme3D {
  // 3D Card Decoration (Kirana & POS items ke liye)
  static BoxDecoration card3D({
    Color color = Colors.white,
    double radius = 12.0,
    Color borderColor = const Color(0xFFE0E0E0),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          offset: const Offset(0, 4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          offset: const Offset(0, 1),
          blurRadius: 3,
        ),
      ],
    );
  }

  // 3D Button Style (Add, Billing, Save ke liye)
  static BoxDecoration button3D({
    Color color = const Color(0xFFFF6B00),
    double radius = 10.0,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.35),
          offset: const Offset(0, 4),
          blurRadius: 8,
        ),
      ],
    );
  }

  // 3D Digital Bill Slip (Printer/Receipt style)
  static BoxDecoration billSlip3D() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDCDCDC), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          offset: const Offset(0, 6),
          blurRadius: 14,
        ),
      ],
    );
  }
}
