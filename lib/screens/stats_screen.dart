import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import '../providers/inventory_providers.dart';
import '../providers/user_provider.dart';
import '../providers/weekly_stats_provider.dart';
import '../theme/app_colors.dart';
import 'quest_log_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  final ValueChanged<QuestModel>? onQuestTap;

  const StatsScreen({super.key, this.onQuestTap});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final GlobalKey _heroOverviewKey = GlobalKey();
  bool _isSharing = false;
  int _recentActivityFilter = 0;

  Future<void> _shareHeroOverview(UserModel? user) async {
    final renderObject = _heroOverviewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    setState(() => _isSharing = true);
    try {
      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('สร้างภาพสถิติไม่สำเร็จ');

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final box = renderObject as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'questhabit-hero-stats.png',
            ),
          ],
          fileNameOverrides: ['questhabit-hero-stats.png'],
          text:
              'เลเวล ${user?.level ?? 1} • ${user?.streakDays ?? 0} วันต่อเนื่อง',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('แชร์สถิติไม่สำเร็จ: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    final weeklyStats = ref.watch(weeklyStatsProvider);
    final heroStats = ref.watch(heroStatsProvider);
    final inventory = ref.watch(inventoryProvider).valueOrNull ?? const [];
    final recentActivities = ref.watch(recentQuestActivitiesProvider);
    final shieldCount = inventory
        .where(
          (entry) =>
              entry.reward.effectType == ItemEffectType.freezeStreakShield,
        )
        .fold<int>(0, (total, entry) => total + entry.item.quantity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const Text(
              'ภาพรวมฮีโร่',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            heroStats.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text('โหลดสถิติไม่สำเร็จ: $error'),
              data: (stats) => _buildHeroOverview(
                stats: stats,
                user: user,
                shieldCount: shieldCount,
                weeklyStats: weeklyStats.valueOrNull ?? const [],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text(
                    'บันทึกชัยชนะรายสัปดาห์',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'สัปดาห์ที่ ${_isoWeekNumber(DateTime.now())}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            weeklyStats.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text('โหลดกราฟไม่สำเร็จ: $error'),
              data: (entries) => Column(
                children: [
                  _buildGuildCalendar(entries, user?.streakDays ?? 0),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(entries),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ไฮไลต์ภารกิจล่าสุด',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onQuestTap == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                QuestLogScreen(onQuestTap: widget.onQuestTap!),
                          ),
                        ),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('ดูทั้งหมด'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRecentFilterChip(label: 'ล่าสุด', index: 0),
                  const SizedBox(width: 8),
                  _buildRecentFilterChip(
                    label: 'เควสต์ทันใจ',
                    index: 1,
                    icon: Icons.bolt_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildRecentFilterChip(
                    label: 'เควสต์โฟกัส',
                    index: 2,
                    icon: Icons.sports_martial_arts_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            recentActivities.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Text('โหลดประวัติไม่สำเร็จ: $error'),
              data: (activities) => _buildRecentQuestHighlights(
                _filterRecentActivities(activities),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFilterChip({
    required String label,
    required int index,
    IconData? icon,
  }) {
    return ChoiceChip(
      selected: _recentActivityFilter == index,
      onSelected: (selected) {
        if (selected) setState(() => _recentActivityFilter = index);
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(label),
        ],
      ),
    );
  }

  List<QuestActivity> _filterRecentActivities(List<QuestActivity> activities) {
    return switch (_recentActivityFilter) {
      1 =>
        activities
            .where(
              (activity) => activity.quest.goalType == QuestGoalType.dailyHabit,
            )
            .toList(),
      2 =>
        activities
            .where((activity) => activity.quest.goalType == QuestGoalType.focus)
            .toList(),
      _ => activities,
    };
  }

  Widget _buildHeroOverview({
    required HeroStats stats,
    required UserModel? user,
    required int shieldCount,
    required List<DailyStatEntry> weeklyStats,
  }) {
    final weekCompleted = weeklyStats.fold<int>(
      0,
      (total, day) => total + day.completedQuestsCount,
    );
    final weekFocusMinutes = weeklyStats.fold<int>(
      0,
      (total, day) => total + day.focusMinutes,
    );
    final averageFocusHours = weekFocusMinutes / 7 / 60;

    return Column(
      children: [
        RepaintBoundary(
          key: _heroOverviewKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'HERO OVERVIEW',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2CC),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.goldRewardDark),
                      ),
                      child: Text(
                        'LEVEL ${user?.level ?? 1}',
                        style: const TextStyle(
                          color: Color(0xFF8A4B08),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.38,
                  ),
                  itemBuilder: (context, index) {
                    return switch (index) {
                      0 => _buildMetricCard(
                        title: 'อัตราความสำเร็จ',
                        value: '${stats.successRate}%',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF166534),
                        detail: '$weekCompleted เควสต์ที่สำเร็จสัปดาห์นี้',
                        detailColor: const Color(0xFF166534),
                      ),
                      1 => _buildMetricCard(
                        title: 'เวลาโฟกัสรวม',
                        value: _formatMinutes(stats.focusMinutes),
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFF0F766E),
                        detail:
                            'เฉลี่ย ${averageFocusHours.toStringAsFixed(1)} ชม./วัน',
                      ),
                      2 => _buildMetricCard(
                        title: 'การปกป้องสตรีค',
                        value: '${user?.streakDays ?? 0} วัน 🔥',
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.streakFlame,
                        detail: 'วินัยต่อเนื่อง',
                        badge: '🛡 x$shieldCount',
                      ),
                      _ => _buildMetricCard(
                        title: 'เควสต์เคลียร์แล้ว',
                        value: 'สำเร็จ ${stats.completedQuests}',
                        icon: Icons.emoji_events_rounded,
                        color: AppColors.goldRewardDark,
                        detail: '+${stats.bossesDefeated} เควสต์บอส',
                        detailColor: const Color(0xFF166534),
                      ),
                    };
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : () => _shareHeroOverview(user),
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: const Text('แชร์สถิติผจญภัย'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14532D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String detail,
    Color detailColor = AppColors.textMuted,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF8),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2CC),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8A4B08),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: detailColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuildCalendar(List<DailyStatEntry> entries, int streakDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = today.subtract(Duration(days: today.weekday - 1));
    final byDate = {for (final entry in entries) _dateKey(entry.date): entry};
    const weekdayLabels = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: _panelDecoration(),
      child: Row(
        children: List.generate(7, (index) {
          final date = firstDay.add(Duration(days: index));
          final entry = byDate[_dateKey(date)];
          final isToday = _sameDate(date, today);
          final hasVictory = (entry?.completedQuestsCount ?? 0) > 0;
          final isStreakDay =
              !date.isAfter(today) &&
              streakDays > 0 &&
              !date.isBefore(today.subtract(Duration(days: streakDays - 1)));
          final icon = hasVictory
              ? Icons.check_rounded
              : isStreakDay
              ? Icons.local_fire_department_rounded
              : Icons.remove_rounded;
          final iconColor = hasVictory
              ? const Color(0xFF166534)
              : isStreakDay
              ? AppColors.streakFlame
              : AppColors.borderLight;

          return Expanded(
            child: Column(
              children: [
                Text(
                  weekdayLabels[index],
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFDCFCE7)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday
                          ? const Color(0xFF166534)
                          : AppColors.borderLight,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
                const SizedBox(height: 5),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isToday
                        ? const Color(0xFF166534)
                        : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWeeklyChart(List<DailyStatEntry> entries) {
    final maximum = entries.fold<int>(
      4,
      (value, entry) => math.max(value, entry.completedQuestsCount),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_rounded, size: 14, color: Color(0xFF166534)),
              SizedBox(width: 5),
              Text(
                'เป้าหมาย 4 เควสต์/วัน',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 136,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.map((day) {
                    final count = day.completedQuestsCount;
                    final barHeight = count == 0
                        ? 3.0
                        : (count / maximum * 92).clamp(5.0, 92.0);
                    return Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 18,
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 94,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 22,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: _barColor(count),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _shortDateLabel(day.date),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _DashedGoalPainter(goalRatio: 4 / maximum),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentQuestHighlights(List<QuestActivity> highlights) {
    if (highlights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: _panelDecoration(),
        child: const Center(
          child: Text(
            'ยังไม่มีชัยชนะในบันทึก',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final activitiesByDate = <String, List<QuestActivity>>{};
    for (final activity in highlights) {
      final key = _dateKey(activity.occurredAt.toLocal());
      activitiesByDate.putIfAbsent(key, () => []).add(activity);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final activities in activitiesByDate.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                Text(
                  _activityGroupLabel(activities.first.occurredAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: AppColors.borderLight)),
              ],
            ),
          ),
          for (final activity in activities) _buildRecentActivityCard(activity),
        ],
      ],
    );
  }

  Widget _buildRecentActivityCard(QuestActivity activity) {
    final quest = activity.quest;
    final isFocus = quest.goalType == QuestGoalType.focus;
    final isCompleted = activity.kind == QuestActivityKind.completed;
    final isCampaignVictory = quest.isCampaign && isCompleted;
    final icon = isCampaignVictory
        ? Icons.military_tech_rounded
        : isFocus
        ? Icons.sports_martial_arts_rounded
        : Icons.bolt_rounded;
    final description = quest.description?.trim();
    final story = switch (activity.kind) {
      QuestActivityKind.checkIn =>
        isFocus
            ? 'ผ่าน Focus checkpoint ${quest.estimatedMinutes} นาที'
            : description != null && description.isNotEmpty
            ? 'เช็กอินสำเร็จ • $description'
            : 'เช็กอินภารกิจประจำวันสำเร็จ',
      QuestActivityKind.completed =>
        description != null && description.isNotEmpty
            ? description
            : quest.isCampaign
            ? 'พิชิตแคมเปญ ${quest.habitTargetDays} วัน'
            : isFocus
            ? 'บันทึก Focus Block ${quest.estimatedMinutes} นาที'
            : 'เคลียร์ภารกิจสำเร็จ',
    };
    final rewardText =
        '+${quest.awardedExp ?? quest.expReward} EXP • '
        '+${quest.awardedGold ?? quest.goldReward} Gold';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCampaignVictory
                  ? const Color(0xFFFFF2CC)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isCampaignVictory
                  ? AppColors.goldRewardDark
                  : const Color(0xFF166534),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quest.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeCompletionTime(activity.occurredAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  story,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                if (isCompleted)
                  Text(
                    rewardText,
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  const Text(
                    'บันทึกการเช็กอิน',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _activityGroupLabel(DateTime occurredAt) {
    final date = occurredAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(eventDay).inDays;
    if (difference == 0) return 'วันนี้';
    if (difference == 1) return 'เมื่อวาน';
    return '${date.day}/${date.month}/${date.year}';
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
    color: AppColors.cardSurface,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.border, width: 1.5),
  );

  Color _barColor(int count) {
    if (count >= 4) return const Color(0xFF166534);
    if (count >= 2) return const Color(0xFFC16645);
    return const Color(0xFFF2B08D);
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes นาที';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours ชม.' : '$hours ชม. $remaining น.';
  }

  String _shortDateLabel(DateTime date) {
    const labels = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    return labels[date.weekday - 1];
  }

  String _relativeCompletionTime(DateTime occurredAt) {
    final date = occurredAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(completedDay).inDays;
    if (difference == 0) {
      return 'วันนี้ ${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
    if (difference == 1) return 'เมื่อวานนี้';
    return '$difference วันที่แล้ว';
  }

  int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstWeekStart = firstThursday.subtract(
      Duration(days: firstThursday.weekday - 1),
    );
    return (DateTime(
              thursday.year,
              thursday.month,
              thursday.day,
            ).difference(firstWeekStart).inDays ~/
            7) +
        1;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _DashedGoalPainter extends CustomPainter {
  final double goalRatio;

  const _DashedGoalPainter({required this.goalRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final y = 18 + (1 - goalRatio.clamp(0.0, 1.0)) * 94;
    final paint = Paint()
      ..color = const Color(0xFF166534).withAlpha(170)
      ..strokeWidth = 1.2;
    const dashWidth = 5.0;
    const gapWidth = 4.0;
    for (var x = 0.0; x < size.width; x += dashWidth + gapWidth) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGoalPainter oldDelegate) =>
      oldDelegate.goalRatio != goalRatio;
}
