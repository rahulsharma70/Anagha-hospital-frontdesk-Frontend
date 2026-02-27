import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Matches web theme hsl(173 58% 39%))
  static const Color primaryColor = Color(0xFF2A9D8F);
  // Secondary Colors (Matches web theme hsl(173 35% 93%))
  static const Color secondaryColor = Color(0xFFE6F3F1);
  // Accent Colors (Matches web theme hsl(15 90% 60%))
  static const Color accentColor = Color(0xFFF4733E);

  // Status Colors
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  // Text Colors
  static const Color textDark = Color(0xFF1B2C33); // Match web foreground
  static const Color textLight =
      Color(0xFF6B7A80); // Match web muted-foreground

  // Background Colors
  static const Color bgLight = Color(0xFFF6F9FA); // Match web background
  static const Color bgWhite = Color(0xFFFFFFFF);

  // Border Colors
  static const Color borderColor = Color(0xFFE2EAEB); // Match web border

  // Web Gradients
  static const LinearGradient gradientHero = LinearGradient(
    colors: [
      Color(0xFF2A9D8F), // hsl(173 58% 39%)
      Color(0xFF22C2CD), // hsl(190 70% 45%)
      Color(0xFF19B2E6), // hsl(200 80% 50%)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientCta = LinearGradient(
    colors: [
      Color(0xFFF4642C), // hsl(15 90% 55%)
      Color(0xFFF8883B), // hsl(25 95% 60%)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientCard = LinearGradient(
    colors: [
      Color(0xFFFFFFFF), // hsl(0 0% 100%)
      Color(0xFFF6F9FA), // hsl(200 20% 98%)
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Box Shadows (Replicating Web Box Shadows)
  static final List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: const Color(0xFF2A9D8F).withOpacity(0.15),
      offset: const Offset(0, 4),
      blurRadius: 20,
      spreadRadius: -4,
    )
  ];

  static final List<BoxShadow> shadowCard = [
    BoxShadow(
      color: const Color(0xFF1B2C33).withOpacity(0.12),
      offset: const Offset(0, 8),
      blurRadius: 30,
      spreadRadius: -12,
    )
  ];
}
