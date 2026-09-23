import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated EXP progress bar — fills smoothly with TweenAnimationBuilder
class ExpBar extends StatelessWidget {
  final int currentExp;
  final int maxExp;
  final double height;
  final bool showLabel;

  const ExpBar({
    super.key,
    required this.currentExp,
    required this.maxExp,
    this.height = 12,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxExp > 0 ? (currentExp / maxExp).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                '$currentExp / $maxExp',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        if (showLabel) const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.expBarBg,
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2 - 1),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, Color(0xFF34D399)],
                              ),
                            ),
                          ),
                        ),
                        // Shimmer stripe overlay
                        if (value > 0)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              widthFactor: value,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withAlpha(0),
                                      Colors.white.withAlpha(51),
                                      Colors.white.withAlpha(0),
                                    ],
                                    stops: const [0, 0.5, 1],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
