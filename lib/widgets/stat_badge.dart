import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum StatBadgeType { level, gold, streak }

/// Reusable stat badge — Level / Gold / Streak display pill
class StatBadge extends StatelessWidget {
  final StatBadgeType type;
  final int value;
  final bool compact;

  const StatBadge({
    super.key,
    required this.type,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, bgColor, label) = _config();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 4),
          Text(
            compact ? '$value' : '$label $value',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color, String) _config() {
    switch (type) {
      case StatBadgeType.level:
        return (Icons.military_tech_rounded, AppColors.primaryDark, AppColors.primaryLight, 'Lv.');
      case StatBadgeType.gold:
        return (Icons.monetization_on_rounded, const Color(0xFFB45309), AppColors.goldLight, '');
      case StatBadgeType.streak:
        return (Icons.local_fire_department_rounded, AppColors.secondary, AppColors.secondaryLight, '🔥');
    }
  }
}
