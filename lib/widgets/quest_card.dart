import 'package:flutter/material.dart';
import '../models/quest_model.dart';
import '../models/quest_enums.dart';
import '../theme/app_colors.dart';

/// Quest card widget — purely presentational, receives callbacks via constructor
class QuestCard extends StatefulWidget {
  final QuestModel quest;
  final VoidCallback? onComplete;
  final VoidCallback? onStartFocus;
  final bool isSelected; // for Focus Screen checklist mode
  final bool isDisabled; // for Focus Screen conflict mode
  final bool checklistMode;

  const QuestCard({
    super.key,
    required this.quest,
    this.onComplete,
    this.onStartFocus,
    this.isSelected = false,
    this.isDisabled = false,
    this.checklistMode = false,
  });

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _completeCtrl;
  late Animation<double> _fadeAnim;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _completeCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _completeCtrl.dispose();
    super.dispose();
  }

  void _handleComplete() async {
    if (_completing) return;
    setState(() => _completing = true);
    await _completeCtrl.forward();
    widget.onComplete?.call();
  }

  Color get _categoryColor {
    switch (widget.quest.category) {
      case QuestCategory.main:
        return AppColors.mainQuestColor;
      case QuestCategory.side:
        return AppColors.sideQuestColor;
      case QuestCategory.daily:
        return AppColors.dailyQuestColor;
    }
  }

  IconData get _activityIcon {
    switch (widget.quest.activityType) {
      case ActivityType.physicalHeavy:
        return Icons.fitness_center_rounded;
      case ActivityType.stillness:
        return Icons.self_improvement_rounded;
      case ActivityType.audioOnly:
        return Icons.headphones_rounded;
      case ActivityType.mental:
        return Icons.psychology_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Opacity(
        opacity: widget.isDisabled ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primaryLight
                : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary
                  : widget.isDisabled
                      ? AppColors.borderLight
                      : AppColors.border,
              width: widget.isSelected ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Category color dot + activity icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _categoryColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _categoryColor, width: 2),
                      ),
                      child: Icon(_activityIcon, size: 18, color: _categoryColor),
                    ),
                    const SizedBox(width: 10),
                    // Title + category chip
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.quest.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  decoration: widget.quest.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: widget.quest.isCompleted
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _CategoryChip(
                                  category: widget.quest.category,
                                  color: _categoryColor),
                              const SizedBox(width: 6),
                              _DifficultyStars(
                                  difficulty: widget.quest.difficulty),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Checklist checkbox
                    if (widget.checklistMode)
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: widget.isSelected
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                  ],
                ),
                // Description
                if (widget.quest.description != null &&
                    widget.quest.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.quest.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                // Rewards + buttons row
                Row(
                  children: [
                    // EXP reward
                    _RewardChip(
                      icon: Icons.star_rounded,
                      label: '+${widget.quest.expReward} EXP',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    _RewardChip(
                      icon: Icons.monetization_on_rounded,
                      label: '+${widget.quest.goldReward} G',
                      color: const Color(0xFFB45309),
                    ),
                    if (widget.quest.estimatedMinutes > 0) ...[
                      const SizedBox(width: 6),
                      _RewardChip(
                        icon: Icons.timer_outlined,
                        label: '${widget.quest.estimatedMinutes}m',
                        color: AppColors.textSecondary,
                      ),
                    ],
                    const Spacer(),
                    // Action buttons
                    if (!widget.checklistMode && !widget.quest.isCompleted) ...[
                      if (widget.onStartFocus != null)
                        _SmallButton(
                          label: 'Focus',
                          icon: Icons.center_focus_strong_rounded,
                          color: AppColors.primary,
                          onTap: widget.onStartFocus,
                        ),
                      const SizedBox(width: 6),
                      if (widget.onComplete != null)
                        _SmallButton(
                          label: 'Done',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.secondary,
                          onTap: _handleComplete,
                        ),
                    ],
                    if (widget.quest.isCompleted)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final QuestCategory category;
  final Color color;
  const _CategoryChip({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        category.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DifficultyStars extends StatelessWidget {
  final int difficulty;
  const _DifficultyStars({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < difficulty ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 10,
          color: i < difficulty
              ? AppColors.difficultyColors[difficulty - 1]
              : AppColors.borderLight,
        );
      }),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RewardChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _SmallButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _SmallButton({required this.label, required this.icon, required this.color, this.onTap});

  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: _pressed
              ? []
              : [BoxShadow(color: widget.color.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Text(widget.label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
