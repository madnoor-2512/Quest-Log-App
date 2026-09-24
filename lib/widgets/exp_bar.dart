import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated EXP progress bar — fills smoothly with TweenAnimationBuilder
class ExpBar extends StatefulWidget {
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
  State<ExpBar> createState() => _ExpBarState();
}

class _ExpBarState extends State<ExpBar> {
  late double _previousRatio;

  double _calculateRatio(int current, int max) {
    return max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _previousRatio = _calculateRatio(widget.currentExp, widget.maxExp);
  }

  @override
  void didUpdateWidget(covariant ExpBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentExp != widget.currentExp ||
        oldWidget.maxExp != widget.maxExp) {
      _previousRatio = _calculateRatio(oldWidget.currentExp, oldWidget.maxExp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetRatio = _calculateRatio(widget.currentExp, widget.maxExp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel)
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
                '${widget.currentExp} / ${widget.maxExp}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        if (widget.showLabel) const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: widget.height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.expBarBg,
                borderRadius: BorderRadius.circular(widget.height / 2),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.height / 2 - 1),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _previousRatio, end: targetRatio),
                  duration: const Duration(milliseconds: 800),
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
