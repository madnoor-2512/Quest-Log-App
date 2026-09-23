import 'package:flutter/material.dart';

/// AppColors — ค่าสีทั้งหมดของ Quest Log Design System
/// สไตล์ Cozy Pixel / Retro Adventure
abstract class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFFFFBEB); // Cream White
  static const Color darkBg = Color(0xFF2D3142); // Dark Charcoal
  static const Color surface = Color(0xFFFFF8E1); // Warm Cream Surface
  static const Color cardSurface = Color(0xFFFFFFFF);

  // Primary — Forest Green
  static const Color primary = Color(0xFF10B981);
  static const Color primaryLight = Color(0xFFD1FAE5);
  static const Color primaryDark = Color(0xFF059669);

  // Secondary — Warm Orange
  static const Color secondary = Color(0xFFF97316);
  static const Color secondaryLight = Color(0xFFFFEDD5);
  static const Color secondaryDark = Color(0xFFEA580C);

  // Border & UI Details
  static const Color border = Color(0xFF374151);
  static const Color borderLight = Color(0xFFD1D5DB);

  // Text
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFBEB);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Category colors
  static const Color mainQuestColor = Color(0xFF10B981); // Green
  static const Color sideQuestColor = Color(0xFF3B82F6); // Blue
  static const Color dailyQuestColor = Color(0xFFF97316); // Orange

  static const Color mainQuest = mainQuestColor;
  static const Color sideQuest = sideQuestColor;
  static const Color dailyQuest = dailyQuestColor;

  // Difficulty colors (1-5)
  static const List<Color> difficultyColors = [
    Color(0xFF10B981), // 1 - Easy - Green
    Color(0xFF84CC16), // 2 - Normal - Lime
    Color(0xFFF59E0B), // 3 - Medium - Amber
    Color(0xFFEF4444), // 4 - Hard - Red
    Color(0xFF7C3AED), // 5 - Nightmare - Purple
  ];

  // Gold color
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFEF3C7);
  static const Color goldReward = gold;
  static const Color goldRewardDark = Color(0xFFD97706);
  static const Color levelGold = Color(0xFFFFD700);

  // Streak
  static const Color streakFlame = Color(0xFFF97316);

  // Exp bar
  static const Color expBarFill = Color(0xFF10B981);
  static const Color expBarBg = Color(0xFFD1FAE5);

  // Shadow
  static const Color shadow = Color(0x1A2D3142);

  // Retro pixel overlay
  static const Color pixelBorder = Color(0xFF374151);
}
