import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/focus_session_model.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/focus_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/quest_card.dart';
import '../widgets/rpg_button.dart';

/// Focus Screen — สองสถานะ:
/// 1) ไม่มี active session -> เลือกเควสที่จะทำพร้อมกัน (conflict-aware)
/// 2) มี active session (จาก activeFocusSessionProvider ซึ่งอ่านจาก DB จริง)
///    -> วงกลม timer + ลิสต์เควสในเซสชัน ที่ complete ได้ทีละอัน
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _timer;
  int? _trackedSessionId;
  int _totalSeconds = 0;
  int _secondsRemaining = 0;
  final ValueNotifier<double> _smoothProgressNotifier =
      ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _timer?.cancel();
    _smoothProgressNotifier.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Timer — คำนวณเวลาที่เหลือจาก started_at + target_duration ของ session
  // จริงใน DB หมุนแบบ smooth 60fps/sub-second ไม่ jump ทีละวิ
  // -------------------------------------------------------------------
  void _syncTicker(FocusSessionModel? session) {
    if (session == null) {
      _timer?.cancel();
      _timer = null;
      _trackedSessionId = null;
      _smoothProgressNotifier.value = 0.0;
      return;
    }
    if (_trackedSessionId == session.id && _timer != null) {
      if (_totalSeconds != session.targetDuration) {
        _startLocalTicker(session);
      }
      return;
    }
    _trackedSessionId = session.id;
    _startLocalTicker(session);
  }

  void _startLocalTicker(FocusSessionModel session) {
    final startedAt = DateTime.parse(session.startedAt);
    _totalSeconds = session.targetDuration;
    final totalMs = _totalSeconds * 1000;

    void tick() {
      final now = DateTime.now();
      final elapsedMs = now.difference(startedAt).inMilliseconds;
      final remainingMs = (totalMs - elapsedMs).clamp(0, totalMs);
      final remainingSec = (remainingMs / 1000).ceil();
      final progress =
          totalMs > 0 ? (remainingMs / totalMs).clamp(0.0, 1.0) : 0.0;

      _smoothProgressNotifier.value = progress;
      if (_secondsRemaining != remainingSec && mounted) {
        setState(() => _secondsRemaining = remainingSec);
      }
    }

    tick();
    _timer?.cancel();
    // Sub-second update for buttery smooth circular rotation
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => tick());
  }

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
    final timeUp = _totalSeconds > 0 && _secondsRemaining <= 0;
    if (!timeUp && session != null) {
      final shouldStop = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ยกเลิก Focus Session?'),
          content: const Text(
            'ถ้าจบก่อนหมดเวลา เควสต์ใน session นี้จะไม่ได้รับรางวัลใดๆ',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ทำต่อ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ยกเลิก Session'),
            ),
          ],
        ),
      );
      if (shouldStop != true) return;
    }
    _timer?.cancel();
    _timer = null;
    _trackedSessionId = null;
    _smoothProgressNotifier.value = 0.0;
    await ref.read(activeFocusSessionProvider.notifier).end();
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
    final sessionQuests = await ref.read(activeSessionQuestsProvider.future);
    final result = await ref
        .read(questActionsProvider.notifier)
        .completeQuest(
          quest.id!,
          isConcurrent: sessionQuests.length > 1,
        );
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings?.soundEnabled ?? true) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (settings?.vibrationEnabled ?? true) {
      await HapticFeedback.mediumImpact();
    }
    // activeSessionQuestsProvider ไม่ได้ผูกกับ questListProvider ที่ถูก
    // invalidate อัตโนมัติใน completeQuest() จึงต้อง invalidate เองตรงนี้
    ref.invalidate(activeSessionQuestsProvider);
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
            _syncTicker(session);
            return session != null
                ? _buildActiveSession(session)
                : _buildSelectionScreen();
          },
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
              data: (quests) {
                if (quests.isEmpty) {
                  return const Center(
                    child: Text(
                      'ไม่มีเควสที่เปิดอยู่ ให้เพิ่มเควสในหน้าแรกก่อน',
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
                    child: Text(
                      'ไม่มีเควสต์ที่ทำพร้อมกันได้กับรายการที่เลือก',
                    ),
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
              // จับเวลาตามเควสที่เลือกจริง (รวม estimated_minutes ของทุกเควส
              // ที่เลือกไว้) แทนที่จะให้ผู้ใช้เลือก preset 25/50 นาทีเอง —
              // ถ้าเควสที่เลือกไม่มีเวลาระบุไว้เลย (estimated_minutes รวม
              // เป็น 0) ใช้ 5 นาทีเป็นขั้นต่ำกันไม่ให้ session เริ่มด้วย
              // เวลา 0 วินาที
              final totalMinutes = selected.fold<int>(
                0,
                (sum, q) => sum + q.estimatedMinutes,
              );
              final effectiveMinutes = totalMinutes > 0 ? totalMinutes : 5;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.isEmpty
                        ? 'ยังไม่ได้เลือกเควส'
                        : 'เลือกแล้ว ${selected.length} เควส • '
                              'รวมเวลาโฟกัส $effectiveMinutes นาที'
                              '${totalMinutes == 0 ? ' (ค่าเริ่มต้น)' : ''}',
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
    final timeUp = _totalSeconds > 0 && _secondsRemaining <= 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: questsAsync.when(
              loading: () => _buildTimerRings(session, const []),
              error: (error, stackTrace) => _buildTimerRings(session, const []),
              data: (quests) => _buildTimerRings(session, quests),
            ),
          ),
          const SizedBox(height: 20),
          RpgButton(
            text: 'จบเซสชัน',
            backgroundColor: AppColors.error,
            borderColor: AppColors.primaryDark,
            onPressed: _endSession,
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'เควสในเซสชันนี้:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: questsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
              data: (quests) {
                if (quests.isEmpty) {
                  return const Center(child: Text('ไม่มีเควสในเซสชันนี้'));
                }
                final completedCount =
                    quests.where((quest) => quest.isCompleted).length;
                final progress = completedCount / quests.length;
                return ListView.builder(
                  itemCount: quests.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  quests.length > 1
                                      ? 'Concurrent Quests'
                                      : 'Focus Quest',
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
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              backgroundColor: AppColors.border,
                              color: AppColors.secondary,
                            ),
                            if (!timeUp)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'เควสต์จะกดสำเร็จได้เมื่อหมดเวลา',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    final q = quests[index - 1];
                    final elapsedSeconds = DateTime.now()
                        .difference(DateTime.parse(session.startedAt))
                        .inSeconds
                        .clamp(0, session.targetDuration);
                    final questProgress = session.targetDuration == 0
                        ? 0.0
                        : elapsedSeconds / session.targetDuration;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  q.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${(questProgress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: q.isCompleted ? 1 : questProgress,
                            minHeight: 7,
                            backgroundColor: AppColors.border,
                            color: q.isCompleted
                                ? AppColors.primary
                                : AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        QuestCard(
                          quest: q,
                          onComplete: q.isCompleted || !timeUp
                              ? null
                              : () => _completeSessionQuest(q),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerRings(
    FocusSessionModel session,
    List<QuestModel> quests,
  ) {
    final sessionProgress = _totalSeconds == 0
        ? 0.0
        : _secondsRemaining / _totalSeconds;
    final isConcurrent = quests.length > 1;
    final ringColors = [
      AppColors.secondary,
      AppColors.primary,
      const Color(0xFFE77855),
      const Color(0xFF7C9A68),
    ];
    final ringCount = quests.isEmpty ? 1 : quests.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isConcurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary),
            ),
            child: Text(
              'Concurrent Focus  •  Synergy +10%',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            for (var index = 0; index < ringCount && index < 3; index++)
              SizedBox(
                width: 240 - (index * 26),
                height: 240 - (index * 26),
                child: CircularProgressIndicator(
                  value: quests.isEmpty || quests[index].isCompleted
                      ? 1
                      : sessionProgress,
                  strokeWidth: index == 0 ? 10 : 7,
                  backgroundColor: AppColors.borderLight,
                  color: ringColors[index],
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(_secondsRemaining),
                  style: GoogleFonts.pressStart2p(
                    fontSize: 24,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _secondsRemaining <= 0
                      ? 'หมดเวลาแล้ว!'
                      : isConcurrent
                          ? '${quests.length} เควสต์กำลังทำพร้อมกัน'
                          : 'กำลังโฟกัส...',
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
}
