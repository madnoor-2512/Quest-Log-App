import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../providers/weekly_stats_provider.dart';
import '../theme/app_colors.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;
    final weeklyStats = ref.watch(weeklyStatsProvider);
    final heroStats = ref.watch(heroStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สถิติฮีโร่ (Hero Stats)',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              heroStats.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Text('โหลดสถิติไม่สำเร็จ: $error'),
                data: (stats) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'ความสำเร็จ',
                            value: '${stats.successRate}%',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.primary,
                            subtitle: '${stats.completedQuests}/${stats.totalQuests} เควสต์',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'เวลาโฟกัส',
                            value: _formatMinutes(stats.focusMinutes),
                            icon: Icons.hourglass_top_rounded,
                            color: AppColors.secondary,
                            subtitle: '${stats.totalExpEarned} EXP ที่ได้รับ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Streak ปัจจุบัน',
                            value: '${user?.streakDays ?? 0} วัน',
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.streakFlame,
                            subtitle: 'ทำต่อเนื่อง',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'เควสต์เคลียร์แล้ว',
                            value: '${stats.completedQuests}',
                            icon: Icons.emoji_events_rounded,
                            color: AppColors.levelGold,
                            subtitle: 'เลเวล ${user?.level ?? 1}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'ความก้าวหน้ารอบ 7 วัน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Weekly Bar Chart Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: weeklyStats.when(
                  loading: () => const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => SizedBox(
                    height: 140,
                    child: Center(child: Text('ข้อผิดพลาด: $e')),
                  ),
                  data: (stats) {
                    return SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: stats.map((day) {
                          final count = day.completedQuestsCount;
                          final height = count == 0 ? 8.0 : (count * 20.0).clamp(12.0, 100.0);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 24,
                                height: height,
                                decoration: BoxDecoration(
                                  color: count > 0 ? AppColors.primary : AppColors.border,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                day.dateLabel,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutesนาที';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hoursชม.' : '$hoursชม. $remainingน.';
  }
}
