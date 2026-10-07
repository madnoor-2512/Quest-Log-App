import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/active_quest_timer_model.dart';
import '../models/focus_session_model.dart';
import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/focus_providers.dart';
import '../providers/quest_providers.dart';
import '../services/audio_feedback_service.dart';
import '../theme/app_colors.dart';
import '../widgets/active_focus_panel.dart';
import '../widgets/quest_card.dart';
import '../widgets/rpg_button.dart';

/// Focus Screen — สองสถานะ:
/// 1) ไม่มี active session -> เลือกเควสที่จะทำพร้อมกัน (conflict-aware)
/// 2) มี active session (จาก activeFocusSessionProvider ซึ่งอ่านจาก DB จริง)
///    -> timer แยกรายเควส พร้อมพื้นที่โฟกัสหลักและ audio mini-player
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // -------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------
  Future<void> _startSession(int minutes) async {
    await ref
        .read(activeFocusSessionProvider.notifier)
        .start(targetDurationSeconds: minutes * 60);
  }

  Future<void> _endSession() async {
    final session = ref.read(activeFocusSessionProvider).valueOrNull;
    if (session != null) {
      final List<QuestModel> sessionQuests =
          ref.read(activeSessionQuestsProvider).valueOrNull ??
          await ref.read(activeSessionQuestsProvider.future);
      if (!mounted) return;
      final timers =
          ref.read(activeQuestTimersProvider).valueOrNull ?? const [];
      final incomplete = sessionQuests.where((q) {
        final t = timers.where((item) => item.questId == q.id).firstOrNull;
        return !q.isCompleted && (t == null || t.remainingSeconds > 0);
      }).toList();

      final penaltyHp = incomplete.fold<int>(
        0,
        (sum, q) => sum + (q.difficulty > 0 ? q.difficulty * 8 : 15),
      );
      final totalPenalty = penaltyHp > 0 ? penaltyHp : 20;

      final shouldStop = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'ยอมแพ้เซสชันนี้?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ภารกิจที่ยังโฟกัสไม่เสร็จจะถูกยกเลิก และฮีโร่จะสูญเสีย HP จากการยอมแพ้การต่อสู้/โฟกัส',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'บทลงโทษ: -$totalPenalty HP 💔',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ทำต่อ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: Text('ยอมแพ้ (เสีย -$totalPenalty HP)'),
            ),
          ],
        ),
      );
      if (shouldStop != true) return;

      await ref
          .read(activeFocusSessionProvider.notifier)
          .abandonSession(penaltyHp: totalPenalty);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ยอมแพ้เซสชัน: ฮีโร่สูญเสีย -$totalPenalty HP 🏳️'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    await ref.read(activeFocusSessionProvider.notifier).end();
  }

  Future<void> _toggleSessionPause() async {
    try {
      final timers = ref.read(activeQuestTimersProvider).valueOrNull ?? [];
      if (timers.isEmpty) return;
      final shouldPause = timers.any((timer) => !timer.isPaused);
      final toggled = await ref
          .read(activeQuestTimersProvider.notifier)
          .setSessionPaused(shouldPause);
      if (!toggled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปลี่ยนสถานะเซสชันไม่สำเร็จ')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปลี่ยนสถานะเซสชันไม่สำเร็จ: $error')),
      );
    }
  }

  void _onQuestTap(
    QuestModel quest,
    List<QuestModel> selected,
    bool isDisabled,
  ) {
    if (isDisabled) {
      final conflictService = ref.read(questConflictServiceProvider);
      final result = conflictService.canAddToSelection(selected, quest);
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.block_rounded,
            color: AppColors.error,
            size: 32,
          ),
          title: const Text('เลือกเควสนี้พร้อมกันไม่ได้'),
          content: Text(
            result.reason ?? 'เควสนี้ทำพร้อมกับเควสที่เลือกไว้แล้วไม่ได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('เข้าใจแล้ว'),
            ),
          ],
        ),
      );
      return;
    }
    ref.read(focusSelectionProvider.notifier).toggle(quest);
  }

  Future<void> _completeSessionQuest(QuestModel quest) async {
    final result = await ref
        .read(activeQuestTimersProvider.notifier)
        .completeQuestManually(quest.id!);
    if (result == null) return;
    ref.read(audioFeedbackServiceProvider).playQuestSuccess();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'สำเร็จเควส "${quest.title}"! ได้รับ +${result.exp} EXP, +${result.gold} Gold'
          '${result.wasCapped ? ' (ถึงเพดานรายวันแล้ว)' : ''}',
        ),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeFocusSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
          data: (session) {
            return session != null
                ? _buildActiveSessionReference(session)
                : _buildSelectionScreen();
          },
        ),
      ),
    );
  }

  Widget _buildActiveSessionReference(FocusSessionModel session) {
    final questsAsync = ref.watch(activeSessionQuestsProvider);
    final timersAsync = ref.watch(activeQuestTimersProvider);

    return questsAsync.when(
      loading: () => _buildActiveSession(session),
      error: (error, stackTrace) =>
          Center(child: Text('โหลดภารกิจไม่สำเร็จ: $error')),
      data: (quests) => timersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('โหลดเวลาไม่สำเร็จ: $error')),
        data: (timers) => ActiveFocusPanel(
          key: ValueKey(session.id),
          quests: quests,
          timers: timers,
          onTogglePause: _toggleSessionPause,
          onAbandon: _endSession,
        ),
      ),
    );
  }

  // --- Screen 1: เลือกเควสก่อนเริ่ม (conflict-aware) ---------------------
  Widget _buildSelectionScreen() {
    final selected = ref.watch(focusSelectionProvider);
    final questsAsync = ref.watch(questListProvider(QuestFilter.incomplete));
    final parallelLimit =
        ref.watch(parallelQuestLimitProvider).valueOrNull ?? 1;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เลือกเควสสำหรับเซสชันโฟกัส',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกได้ $parallelLimit เควส ระบบจะแสดงเฉพาะกิจกรรมที่ทำควบคู่กันได้',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: questsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
              data: (allQuests) {
                // หน้าโฟกัสรับได้เฉพาะ "เควสต์โฟกัส" (goalType == focus)
                // เท่านั้น — "เควสต์ทันใจ" (Daily Habit) จบเควสต์ผ่านปุ่ม
                // เช็กอินที่หน้าหลักเท่านั้น การส่งเข้ามาที่นี่แล้วพยายาม
                // completeQuest() ตอนจบเซสชันจะ throw StateError เสมอ
                final quests = allQuests.where((q) {
                  if (q.goalType != QuestGoalType.focus) return false;
                  final allowedWeekdays = q.effectiveHabitWeekdays;
                  return allowedWeekdays.isEmpty ||
                      allowedWeekdays.contains(DateTime.now().weekday);
                }).toList();
                if (quests.isEmpty) {
                  return const Center(
                    child: Text(
                      'ไม่มีเควสโฟกัสที่เปิดอยู่ ให้เพิ่มเควสโฟกัสในหน้าแรกก่อน',
                    ),
                  );
                }
                final blocked = ref.watch(blockedQuestIdsProvider(quests));
                final compatibleQuests = quests
                    .where(
                      (quest) =>
                          selected.any((item) => item.id == quest.id) ||
                          !blocked.contains(quest.id),
                    )
                    .toList();
                if (compatibleQuests.isEmpty) {
                  return const Center(
                    child: Text('ไม่มีเควสต์ที่ทำพร้อมกันได้กับรายการที่เลือก'),
                  );
                }
                return ListView.builder(
                  itemCount: compatibleQuests.length,
                  itemBuilder: (context, index) {
                    final q = compatibleQuests[index];
                    final isSelected = selected.any((sq) => sq.id == q.id);
                    final isDisabled = !isSelected && blocked.contains(q.id);
                    return GestureDetector(
                      onTap: () => _onQuestTap(q, selected, isDisabled),
                      child: QuestCard(
                        quest: q,
                        checklistMode: true,
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // เควสต์ที่ไม่ได้ระบุเวลาใช้เวลาของเควสต์ที่นานที่สุดเป็น fallback
              // และใช้ 5 นาทีเมื่อทุกเควสต์ไม่มีเวลาระบุ
              final longestMinutes = selected.fold<int>(
                0,
                (longest, q) =>
                    q.estimatedMinutes > longest ? q.estimatedMinutes : longest,
              );
              final effectiveMinutes = longestMinutes > 0 ? longestMinutes : 5;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.isEmpty
                        ? 'ยังไม่ได้เลือกเควส'
                        : 'เลือกแล้ว ${selected.length} เควส • '
                              'เวลา fallback $effectiveMinutes นาที'
                              '${longestMinutes == 0 ? ' (ค่าเริ่มต้น)' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RpgButton(
                    text: selected.length > 1
                        ? 'Start Concurrent Focus'
                        : 'Start Focus',
                    backgroundColor: AppColors.primary,
                    borderColor: AppColors.primaryDark,
                    width: double.infinity,
                    onPressed: selected.isEmpty
                        ? null
                        : () => _startSession(effectiveMinutes),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Screen 2: active session -----------------------------------------
  Widget _buildActiveSession(FocusSessionModel session) {
    final questsAsync = ref.watch(activeSessionQuestsProvider);
    final timersAsync = ref.watch(activeQuestTimersProvider);
    final timers = timersAsync.valueOrNull ?? const <ActiveQuestTimer>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        children: [
          Center(
            child: questsAsync.when(
              loading: () => _buildMainFocusArea(const [], timers),
              error: (error, stackTrace) =>
                  _buildMainFocusArea(const [], timers),
              data: (quests) => _buildMainFocusArea(quests, timers),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('จบเซสชัน'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.borderLight),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: questsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
                    data: (quests) {
                      if (timersAsync.hasError) {
                        return Center(
                          child: Text('ข้อผิดพลาด: ${timersAsync.error}'),
                        );
                      }
                      if (!timersAsync.hasValue) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (quests.isEmpty) {
                        return const Center(
                          child: Text('ไม่มีเควสในเซสชันนี้'),
                        );
                      }
                      final timerByQuestId = {
                        for (final timer in timers) timer.questId: timer,
                      };
                      final questById = {
                        for (final quest in quests) quest.id: quest,
                      };
                      final primaryFocusQuestId = timers
                          .where((timer) {
                            return questById[timer.questId] != null &&
                                !questById[timer.questId]!
                                    .activityType
                                    .isBackgroundAllowed;
                          })
                          .firstOrNull
                          ?.questId;
                      final secondaryQuests = quests.where((quest) {
                        return quest.id != primaryFocusQuestId &&
                            !quest.activityType.isBackgroundAllowed;
                      }).toList();
                      final completedCount = quests.where((quest) {
                        return quest.isCompleted ||
                            !timerByQuestId.containsKey(quest.id);
                      }).length;
                      final progress = completedCount / quests.length;
                      final audioQuestCount = timers.where((timer) {
                        return questById[timer.questId]
                                ?.activityType
                                .isBackgroundAllowed ??
                            false;
                      }).length;
                      final bottomScrollSpace = audioQuestCount == 0
                          ? 8.0
                          : audioQuestCount * 34.0 + 10.0;
                      return ListView.builder(
                        padding: EdgeInsets.only(bottom: bottomScrollSpace),
                        itemCount: secondaryQuests.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        secondaryQuests.isEmpty
                                            ? 'ไม่มีภารกิจรอง'
                                            : 'ภารกิจรอง',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '$completedCount/${quests.length} สำเร็จ',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(8),
                                    backgroundColor: AppColors.border,
                                    color: AppColors.secondary,
                                  ),
                                ],
                              ),
                            );
                          }
                          final q = secondaryQuests[index - 1];
                          final timer = timerByQuestId[q.id];
                          final isFinished = q.isCompleted || timer == null;
                          final questProgress = isFinished
                              ? 1.0
                              : timer.progress;
                          final displayQuest = isFinished && !q.isCompleted
                              ? q.copyWith(isCompleted: true)
                              : q;
                          if (timer?.completionError != null) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'ทำเควสต์อัตโนมัติไม่สำเร็จ: ${timer!.completionError}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return QuestCard(
                            quest: displayQuest,
                            progress: questProgress,
                            progressLabel: '${(questProgress * 100).round()}%',
                            onComplete:
                                isFinished ||
                                    q.isCampaign ||
                                    timer.remainingSeconds > 0
                                ? null
                                : () => _completeSessionQuest(q),
                          );
                        },
                      );
                    },
                  ),
                ),
                questsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (quests) => _buildAudioMiniPlayer(quests, timers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFocusArea(
    List<QuestModel> quests,
    List<ActiveQuestTimer> timers,
  ) {
    final questById = {for (final quest in quests) quest.id: quest};
    final mainTimers = timers.where((timer) {
      final quest = questById[timer.questId];
      return quest != null && !quest.activityType.isBackgroundAllowed;
    }).toList();
    if (mainTimers.isEmpty) {
      final hasBackgroundQuest = timers.any((timer) {
        return questById[timer.questId]?.activityType.isBackgroundAllowed ??
            false;
      });
      return SizedBox(
        height: 175,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasBackgroundQuest
                    ? Icons.headphones_rounded
                    : Icons.check_circle_outline_rounded,
                size: 44,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 10),
              Text(
                hasBackgroundQuest
                    ? 'กำลังทำเควสเสียงเบื้องหลัง'
                    : 'ไม่มีเควสหลักที่กำลังนับเวลา',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final timer = mainTimers.first;
    final quest = questById[timer.questId]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mainTimers.length > 1
              ? 'โฟกัสหลัก • ${mainTimers.length} เควส'
              : 'โฟกัสหลัก',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          quest.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 156,
              height: 156,
              child: CircularProgressIndicator(
                value: timer.progress,
                strokeWidth: 8,
                backgroundColor: AppColors.borderLight,
                color: AppColors.secondary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timer.isPaused
                      ? 'หยุดชั่วคราว'
                      : _formatTime(timer.remainingSeconds),
                  style: timer.isPaused
                      ? const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )
                      : GoogleFonts.robotoMono(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  mainTimers.length > 1
                      ? '${(timer.progress * 100).round()}% • ${mainTimers.length} ภารกิจ'
                      : '${(timer.progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioMiniPlayer(
    List<QuestModel> quests,
    List<ActiveQuestTimer> timers,
  ) {
    final questById = {for (final quest in quests) quest.id: quest};
    final audioTimers = timers.where((timer) {
      return questById[timer.questId]?.activityType.isBackgroundAllowed ??
          false;
    }).toList();
    if (audioTimers.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < audioTimers.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.headphones_rounded,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      questById[audioTimers[index].questId]?.title ??
                          'เควสเสียง',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(audioTimers[index].remainingSeconds),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: audioTimers[index].isPaused
                        ? 'เล่นเควสต่อ'
                        : 'หยุดเควสชั่วคราว',
                    visualDensity: VisualDensity.compact,
                    onPressed: _toggleSessionPause,
                    icon: Icon(
                      audioTimers[index].isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
