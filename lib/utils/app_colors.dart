import 'package:flutter/material.dart';

class AppColors {
  // Primary palette extracted from icon
  static const Color primaryTeal = Color(0xFF269092);
  static const Color primaryBlue = Color(0xFF05445E);
  static const Color accentTeal = Color(0xFF75E6DA);
  static const Color navyBlue = Color(0xFF189AB4);
  static const Color silver = Color(0xFFD4D4D4);

  // Neutral colors
  static const Color background = Color(0xFFF0F2F5);
  static const Color white = Colors.white;
  static const Color black = Color(0xFF1A1A1A);

  // Gradient for background as seen in the icon
  static const LinearGradient iconGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryTeal, primaryBlue],
  );

  static const RadialGradient radialGradient = RadialGradient(
    colors: [accentTeal, primaryTeal, primaryBlue],
    center: Alignment.center,
    radius: 0.8,
  );
}
