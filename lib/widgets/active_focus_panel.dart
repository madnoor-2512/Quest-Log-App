import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/active_quest_timer_model.dart';
import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../theme/app_colors.dart';

class ActiveFocusPanel extends StatelessWidget {
  final List<QuestModel> quests;
  final List<ActiveQuestTimer> timers;
  final VoidCallback onTogglePause;
  final VoidCallback onAbandon;

  const ActiveFocusPanel({
    super.key,
    required this.quests,
    required this.timers,
    required this.onTogglePause,
    required this.onAbandon,
  });

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  Color _timerColor(QuestModel quest) {
    return switch (quest.activityType) {
      ActivityType.physicalHeavy => AppColors.primaryDark,
      ActivityType.stillness => AppColors.secondary,
      ActivityType.audioOnly => AppColors.info,
      ActivityType.mental => AppColors.secondaryDark,
      ActivityType.visual => const Color(0xFF528B8B),
    };
  }

  String _activityCode(ActivityType activityType) {
    return switch (activityType) {
      ActivityType.physicalHeavy => 'STR',
      ActivityType.stillness => 'RST',
      ActivityType.audioOnly => 'AUD',
      ActivityType.mental => 'INT',
      ActivityType.visual => 'VIS',
    };
  }

  @override
  Widget build(BuildContext context) {
    final timerById = {for (final timer in timers) timer.questId: timer};
    final questById = {for (final quest in quests) quest.id: quest};
    final activeTimers = timers
        .where((timer) => timer.remainingSeconds > 0)
        .toList();
    final isPaused =
        activeTimers.isNotEmpty &&
        activeTimers.every((timer) => timer.isPaused);
    final completedCount = quests.where((quest) {
      return quest.isCompleted || !timerById.containsKey(quest.id);
    }).length;
    final overallProgress = quests.isEmpty
        ? 0.0
        : quests.fold<double>(0, (sum, quest) {
                final timer = timerById[quest.id];
                return sum +
                    (quest.isCompleted || timer == null ? 1 : timer.progress);
              }) /
              quests.length;
    final visualTimers = [...activeTimers]
      ..sort((first, second) {
        final firstIsBackground =
            questById[first.questId]?.activityType.isBackgroundAllowed ?? false;
        final secondIsBackground =
            questById[second.questId]?.activityType.isBackgroundAllowed ??
            false;
        if (firstIsBackground == secondIsBackground) return 0;
        return firstIsBackground ? 1 : -1;
      });
    final ringTimers = visualTimers.take(3).toList();
    final primaryTimer = ringTimers.firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 680;
        final horizontalPadding = constraints.maxWidth < 380 ? 12.0 : 20.0;
        final verticalPadding = compact ? 8.0 : 14.0;
        final minHeight = math.max(
          0.0,
          constraints.maxHeight - verticalPadding * 2,
        );
        final ringSize = math.min(
          constraints.maxWidth - horizontalPadding * 2 - 36,
          compact ? 214.0 : 250.0,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSessionCard(
                  compact: compact,
                  ringSize: ringSize,
                  ringTimers: ringTimers,
                  primaryTimer: primaryTimer,
                  isPaused: isPaused,
                  activeCount: activeTimers.length,
                  completedCount: completedCount,
                  overallProgress: overallProgress,
                  timerById: timerById,
                ),
                SizedBox(height: compact ? 12 : 18),
                _buildControls(
                  isPaused: isPaused,
                  hasActiveTimers: activeTimers.isNotEmpty,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionCard({
    required bool compact,
    required double ringSize,
    required List<ActiveQuestTimer> ringTimers,
    required ActiveQuestTimer? primaryTimer,
    required bool isPaused,
    required int activeCount,
    required int completedCount,
    required double overallProgress,
    required Map<int?, ActiveQuestTimer> timerById,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DFC6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2D3142),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFC8DCC8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: isPaused
                        ? AppColors.textMuted
                        : AppColors.primaryDark,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isPaused
                        ? 'พักภารกิจไว้แล้ว'
                        : 'กำลังทำพร้อมกัน $activeCount ภารกิจ',
                    style: const TextStyle(
                      color: Color(0xFF315B32),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var index = 0; index < ringTimers.length; index++)
                  SizedBox(
                    width: ringSize - index * 22,
                    height: ringSize - index * 22,
                    child: CircularProgressIndicator(
                      value: ringTimers[index].progress,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFE7E2D7),
                      color: _timerColor(
                        quests.firstWhere(
                          (quest) => quest.id == ringTimers[index].questId,
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'เวลาที่เหลือ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryTimer == null
                          ? '00:00'
                          : _formatTime(primaryTimer.remainingSeconds),
                      style: GoogleFonts.robotoMono(
                        color: AppColors.textPrimary,
                        fontSize: compact ? 30 : 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: isPaused
                              ? AppColors.textMuted
                              : AppColors.primaryDark,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isPaused ? 'หยุดชั่วคราว' : 'กำลังเดินเวลา',
                          style: const TextStyle(
                            color: Color(0xFF315B32),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          const Divider(color: Color(0xFFE8DFC6), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ภารกิจที่กำลังทำพร้อมกัน ($activeCount)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ความคืบหน้ารวม ${(overallProgress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (quests.isEmpty)
            const Text('ไม่มีภารกิจในเซสชันนี้')
          else
            for (final quest in quests)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildActiveQuestCard(quest, timerById[quest.id]),
              ),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE7E2D7),
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completedCount/${quests.length}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveQuestCard(QuestModel quest, ActiveQuestTimer? timer) {
    final color = _timerColor(quest);
    final isFinished = quest.isCompleted || timer == null;
    final progress = isFinished ? 1.0 : timer.progress;
    final targetMinutes = timer == null
        ? quest.estimatedMinutes
        : (timer.targetDurationSeconds / 60).ceil();
    final typeCode = _activityCode(quest.activityType);

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DFC6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(
                  typeCode,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timer == null
                        ? 'เสร็จแล้ว'
                        : _formatTime(timer.remainingSeconds),
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (timer?.isPaused == true)
                    const Text(
                      'พักอยู่',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                targetMinutes > 0
                    ? 'เป้าหมาย: $targetMinutes นาที${quest.isCampaign ? ' (ต่อเนื่อง)' : ''}'
                    : 'ภารกิจพร้อมทำ',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE7E2D7),
              color: color,
            ),
          ),
          if (timer?.completionError != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ทำภารกิจไม่สำเร็จ: ${timer!.completionError}',
                  style: const TextStyle(color: AppColors.error, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls({
    required bool isPaused,
    required bool hasActiveTimers,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: hasActiveTimers ? onTogglePause : null,
            icon: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 23,
            ),
            label: Text(
              isPaused ? 'เล่นต่อ' : 'หยุดชั่วคราว',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.borderLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: onAbandon,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('ยอมแพ้ (ยกเลิกทุกภารกิจ)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: Color(0xFFE8DFC6)),
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
