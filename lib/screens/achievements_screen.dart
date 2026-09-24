import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement_model.dart';
import '../providers/achievements_providers.dart';
import '../theme/app_colors.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  IconData _iconFor(String name) {
    switch (name) {
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(unlockedAchievementCodesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ความสำเร็จ (Achievements)')),
      body: SafeArea(
        child: unlockedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
          data: (unlockedCodes) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ปลดล็อกแล้ว ${unlockedCodes.length} / ${kAchievementCatalog.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: kAchievementCatalog.length,
                      itemBuilder: (context, index) {
                        final def = kAchievementCatalog[index];
                        final unlocked = unlockedCodes.contains(def.code);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: unlocked
                                ? AppColors.cardSurface
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: unlocked
                                  ? AppColors.levelGold
                                  : AppColors.borderLight,
                              width: unlocked ? 2 : 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: unlocked
                                      ? AppColors.levelGold.withAlpha(45)
                                      : AppColors.borderLight.withAlpha(60),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  unlocked
                                      ? _iconFor(def.iconName)
                                      : Icons.lock_outline_rounded,
                                  color: unlocked
                                      ? AppColors.goldRewardDark
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      def.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: unlocked
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      def.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (unlocked)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
