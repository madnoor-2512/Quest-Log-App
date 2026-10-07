import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/active_quest_timer_model.dart';
import '../models/quest_model.dart';
import '../models/focus_session_model.dart';
import '../models/reward_model.dart';
import '../services/audio_feedback_service.dart';
import '../services/quest_conflict_service.dart';
import 'core_providers.dart';
import 'quest_providers.dart';
import 'user_provider.dart';

final focusSelectionProvider =
    NotifierProvider<FocusSelectionNotifier, List<QuestModel>>(
      FocusSelectionNotifier.new,
    );

class FocusSelectionNotifier extends Notifier<List<QuestModel>> {
  @override
  List<QuestModel> build() => const [];

  void add(QuestModel quest) {
    if (state.any((q) => q.id == quest.id)) return;
    if (state.length >= QuestConflictService.maxParallelQuests) return;
    state = [...state, quest];
  }

  void remove(int questId) {
    state = state.where((q) => q.id != questId).toList();
  }

  void toggle(QuestModel quest) {
    if (state.any((q) => q.id == quest.id)) {
      remove(quest.id!);
    } else {
      add(quest);
    }
  }

  void clear() => state = const [];
}

final parallelQuestLimitProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(userProvider).valueOrNull;
  var limit = user?.rpgClass == null ? 1 : 2;
  final equipped = await ref
      .read(databaseHelperProvider)
      .getEquippedEquipment();
  if (equipped?.effectType == ItemEffectType.parallelQuestSlot) {
    limit = 3;
  }
  return limit;
});

final blockedQuestIdsProvider = Provider.family<Set<int>, List<QuestModel>>((
  ref,
  candidates,
) {
  final selected = ref.watch(focusSelectionProvider);
  final conflictService = ref.watch(questConflictServiceProvider);
  final limit = ref.watch(parallelQuestLimitProvider).valueOrNull ?? 1;
  return conflictService.getBlockedQuestIds(
    selected,
    candidates,
    maxParallelQuests: limit,
  );
});

final activeFocusSessionProvider =
    AsyncNotifierProvider<ActiveFocusSessionNotifier, FocusSessionModel?>(
      ActiveFocusSessionNotifier.new,
    );

class ActiveFocusSessionNotifier extends AsyncNotifier<FocusSessionModel?> {
  @override
  Future<FocusSessionModel?> build() async {
    final db = ref.read(databaseHelperProvider);
    return db.getActiveFocusSession();
  }

  Future<void> start({required int targetDurationSeconds}) async {
    final selected = ref.read(focusSelectionProvider);
    if (selected.isEmpty) return;
    final limit = await ref.read(parallelQuestLimitProvider.future);
    if (selected.length > limit) {
      throw StateError('Concurrent Quest slot is limited to $limit.');
    }

    final db = ref.read(databaseHelperProvider);
    var durationMultiplier = 1.0;
    final equipped = await db.getEquippedEquipment();
    if (equipped != null &&
        equipped.effectType == ItemEffectType.focusTimeBonusPercent &&
        equipped.effectValue != null) {
      durationMultiplier += equipped.effectValue!;
    }
    final questDurations = {
      for (final quest in selected)
        quest.id!:
            ((quest.estimatedMinutes > 0
                        ? quest.estimatedMinutes * 60
                        : targetDurationSeconds) *
                    durationMultiplier)
                .round(),
    };

    final startedAt = DateTime.now().toIso8601String();

    final sessionId = await db.startFocusSession(
      startedAt: startedAt,
      questDurations: questDurations,
    );

    final activeSession = await db.getActiveFocusSession();
    ref.read(focusSelectionProvider.notifier).clear();
    state = AsyncValue.data(
      activeSession ?? FocusSessionModel(id: sessionId, startedAt: startedAt),
    );
    ref.invalidate(activeSessionQuestsProvider);
    ref.invalidate(activeQuestTimersProvider);
    await ref.read(activeQuestTimersProvider.future);
  }

  /// บวกเวลาเพิ่มให้ session ที่กำลัง active อยู่ทันที (ใช้จากไอเทม
  /// consumable "คัมภีร์ยืดเวลา" effectType: extendFocusMinutes) — เพิ่มเวลา
  /// ให้ timer ของทุกเควสที่ยังทำงานอยู่
  Future<bool> extendActiveSession(int extraMinutes) async {
    final session = state.valueOrNull;
    if (session?.id == null) return false;
    return ref
        .read(activeQuestTimersProvider.notifier)
        .extendActiveTimers(extraMinutes * 60);
  }

  Future<void> end() async {
    final session = state.valueOrNull;
    if (session?.id == null) return;
    await ref.read(databaseHelperProvider).endFocusSession(session!.id!);
    state = const AsyncValue.data(null);
    ref.read(activeQuestTimersProvider.notifier).clear();
    ref.invalidate(activeSessionQuestsProvider);
  }

  /// ผู้เล่นกดยอมแพ้เซสชันโฟกัส (Abandon Focus Session)
  /// หัก HP ของฮีโร่ตามบทลงโทษ และหยุดเซสชันในฐานข้อมูล
  Future<void> abandonSession({int penaltyHp = 20}) async {
    final session = state.valueOrNull;
    if (session?.id == null) return;
    if (penaltyHp > 0) {
      await ref.read(userProvider.notifier).applyHpDamage(penaltyHp);
    }
    await ref.read(databaseHelperProvider).endFocusSession(session!.id!);
    state = const AsyncValue.data(null);
    ref.read(activeQuestTimersProvider.notifier).clear();
    ref.invalidate(activeSessionQuestsProvider);
  }
}

final activeQuestTimersProvider =
    AsyncNotifierProvider<ActiveQuestTimersNotifier, List<ActiveQuestTimer>>(
      ActiveQuestTimersNotifier.new,
    );

class ActiveQuestTimersNotifier extends AsyncNotifier<List<ActiveQuestTimer>> {
  Timer? _ticker;
  final Set<int> _completingQuestIds = {};
  final Set<int> _failedQuestIds = {};

  @override
  Future<List<ActiveQuestTimer>> build() async {
    _ticker?.cancel();
    _failedQuestIds.clear();
    final session = await ref.watch(activeFocusSessionProvider.future);
    if (session?.id == null) return const [];

    final rows = await ref
        .read(databaseHelperProvider)
        .getFocusSessionQuestDurations(session!.id!);
    final now = DateTime.now();
    final timers = rows.map((row) {
      final startedAt = row.startedAt ?? session.startedAt;
      final elapsedUntil = row.isPaused && row.pausedAt != null
          ? DateTime.parse(row.pausedAt!)
          : now;
      final remaining =
          (row.targetDurationSeconds -
                  elapsedUntil.difference(DateTime.parse(startedAt)).inSeconds)
              .clamp(0, row.targetDurationSeconds);
      return ActiveQuestTimer(
        questId: row.questId,
        startedAt: startedAt,
        targetDurationSeconds: row.targetDurationSeconds,
        remainingSeconds: remaining,
        isPaused: row.isPaused,
        pausedAt: row.pausedAt,
      );
    }).toList();

    if (timers.isNotEmpty) {
      final ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tick(session),
      );
      _ticker = ticker;
      ref.onDispose(ticker.cancel);
      if (timers.any((timer) => timer.remainingSeconds == 0)) {
        scheduleMicrotask(() => _tick(session));
      }
    }
    return timers;
  }

  void _tick(FocusSessionModel session) {
    final current = state.valueOrNull;
    if (current == null) return;
    final now = DateTime.now();
    final updated = current.map((timer) {
      final elapsedUntil = timer.isPaused && timer.pausedAt != null
          ? DateTime.parse(timer.pausedAt!)
          : now;
      final elapsed = elapsedUntil
          .difference(DateTime.parse(timer.startedAt))
          .inSeconds;
      return timer.copyWith(
        remainingSeconds: (timer.targetDurationSeconds - elapsed).clamp(
          0,
          timer.targetDurationSeconds,
        ),
      );
    }).toList();
    state = AsyncValue.data(updated);

    for (final timer in updated) {
      if (timer.remainingSeconds == 0 &&
          !timer.isPaused &&
          !_completingQuestIds.contains(timer.questId) &&
          !_failedQuestIds.contains(timer.questId)) {
        unawaited(_completeExpiredQuest(session, timer));
      }
    }
  }

  Future<void> _completeExpiredQuest(
    FocusSessionModel session,
    ActiveQuestTimer timer,
  ) async {
    final questId = timer.questId;
    if (!_completingQuestIds.add(questId)) return;
    try {
      final db = ref.read(databaseHelperProvider);
      final sessionQuests = await db.getQuestsInSession(session.id!);
      QuestModel? quest;
      for (final candidate in sessionQuests) {
        if (candidate.id == questId) {
          quest = candidate;
          break;
        }
      }

      if (quest == null || quest.isCompleted) {
        await _removeCompletedTimer(session, questId);
        return;
      }
      if (quest.isCampaign) {
        await ref
            .read(questActionsProvider.notifier)
            .checkInHabit(questId, fromFocusTimer: true);
      } else {
        await ref
            .read(questActionsProvider.notifier)
            .completeQuest(
              questId,
              isConcurrent: sessionQuests.length > 1,
              fromFocus: true,
              focusCompletionRatio: 1,
            );
      }
      ref.read(audioFeedbackServiceProvider).playFocusComplete();
      await _removeCompletedTimer(session, questId);
    } catch (error) {
      _failedQuestIds.add(questId);
      state = AsyncValue.data([
        for (final current in state.valueOrNull ?? const <ActiveQuestTimer>[])
          current.questId == questId
              ? current.copyWith(completionError: error.toString())
              : current,
      ]);
    } finally {
      _completingQuestIds.remove(questId);
    }
  }

  Future<void> _removeCompletedTimer(
    FocusSessionModel session,
    int questId,
  ) async {
    _failedQuestIds.remove(questId);
    final remaining = (state.valueOrNull ?? const <ActiveQuestTimer>[])
        .where((timer) => timer.questId != questId)
        .toList();
    state = AsyncValue.data(remaining);
    ref.invalidate(activeSessionQuestsProvider);
    if (remaining.isEmpty &&
        ref.read(activeFocusSessionProvider).valueOrNull?.id == session.id) {
      await ref.read(activeFocusSessionProvider.notifier).end();
    }
  }

  Future<({int exp, int gold, bool wasCapped})?> completeQuestManually(
    int questId,
  ) async {
    final session = ref.read(activeFocusSessionProvider).valueOrNull;
    final timer = (state.valueOrNull ?? const <ActiveQuestTimer>[])
        .where((item) => item.questId == questId)
        .firstOrNull;
    if (session?.id == null || timer == null || timer.remainingSeconds > 0) {
      return null;
    }
    if (!_completingQuestIds.add(questId)) return null;
    _failedQuestIds.remove(questId);
    try {
      final sessionQuests = await ref
          .read(databaseHelperProvider)
          .getQuestsInSession(session!.id!);
      final result = await ref
          .read(questActionsProvider.notifier)
          .completeQuest(
            questId,
            isConcurrent: sessionQuests.length > 1,
            fromFocus: true,
            focusCompletionRatio: 1,
          );
      await _removeCompletedTimer(session, questId);
      return (exp: result.exp, gold: result.gold, wasCapped: result.wasCapped);
    } catch (error) {
      _failedQuestIds.add(questId);
      state = AsyncValue.data([
        for (final current in state.valueOrNull ?? const <ActiveQuestTimer>[])
          current.questId == questId
              ? current.copyWith(completionError: error.toString())
              : current,
      ]);
      return null;
    } finally {
      _completingQuestIds.remove(questId);
    }
  }

  Future<bool> extendActiveTimers(int extraSeconds) async {
    final timers = state.valueOrNull ?? await future;
    final session = ref.read(activeFocusSessionProvider).valueOrNull;
    final runningTimers = timers
        .where(
          (timer) =>
              timer.remainingSeconds > 0 &&
              !_completingQuestIds.contains(timer.questId),
        )
        .toList();
    if (runningTimers.isEmpty || session?.id == null || extraSeconds <= 0) {
      return false;
    }
    await ref
        .read(databaseHelperProvider)
        .extendFocusSessionQuestTimers(
          session!.id!,
          runningTimers.map((timer) => timer.questId).toList(),
          extraSeconds,
        );
    state = AsyncValue.data([
      for (final timer in timers)
        if (runningTimers.any((running) => running.questId == timer.questId))
          timer.copyWith(
            targetDurationSeconds: timer.targetDurationSeconds + extraSeconds,
            remainingSeconds: timer.remainingSeconds + extraSeconds,
            clearCompletionError: true,
          )
        else
          timer,
    ]);
    return true;
  }

  Future<bool> toggleQuestTimer(int questId) async {
    final timers = state.valueOrNull ?? await future;
    final timer = timers.where((item) => item.questId == questId).firstOrNull;
    final session = ref.read(activeFocusSessionProvider).valueOrNull;
    if (timer == null || session?.id == null) return false;

    final db = ref.read(databaseHelperProvider);
    if (timer.isPaused) {
      final now = DateTime.now();
      final pausedAt = timer.pausedAt == null
          ? now
          : DateTime.parse(timer.pausedAt!);
      final elapsed = pausedAt.difference(DateTime.parse(timer.startedAt));
      final resumedStartedAt = now.subtract(elapsed).toIso8601String();
      final updatedRows = await db.resumeFocusSessionQuestTimer(
        session!.id!,
        questId,
        resumedStartedAt,
      );
      if (updatedRows == 0) return false;
      state = AsyncValue.data([
        for (final current in timers)
          current.questId == questId
              ? current.copyWith(
                  startedAt: resumedStartedAt,
                  isPaused: false,
                  clearPausedAt: true,
                )
              : current,
      ]);
      return true;
    }

    if (timer.remainingSeconds <= 0 || _completingQuestIds.contains(questId)) {
      return false;
    }
    final pausedAt = DateTime.now().toIso8601String();
    final updatedRows = await db.pauseFocusSessionQuestTimer(
      session!.id!,
      questId,
      pausedAt,
    );
    if (updatedRows == 0) return false;
    state = AsyncValue.data([
      for (final current in timers)
        current.questId == questId
            ? current.copyWith(isPaused: true, pausedAt: pausedAt)
            : current,
    ]);
    return true;
  }

  Future<bool> setSessionPaused(bool shouldPause) async {
    final timers = state.valueOrNull ?? await future;
    var changed = false;
    for (final timer in timers) {
      if (timer.isPaused == shouldPause) continue;
      changed = await toggleQuestTimer(timer.questId) || changed;
    }
    return changed;
  }

  /// บังคับหยุด Timer ของเควสต์ที่ระบุอย่างปลอดภัย เพื่อป้องกันข้อผิดพลาดเวลาเควสต์ถูกลบ
  Future<void> forceStopTimer(int questId) async {
    final session = ref.read(activeFocusSessionProvider).valueOrNull;
    if (session?.id != null) {
      final db = ref.read(databaseHelperProvider);
      await db.removeQuestFromFocusSession(session!.id!, questId);
      await _removeCompletedTimer(session, questId);
    }
  }

  void clear() {
    _ticker?.cancel();
    _ticker = null;
    _failedQuestIds.clear();
    _completingQuestIds.clear();
    state = const AsyncValue.data([]);
  }
}

final activeSessionQuestsProvider = FutureProvider<List<QuestModel>>((
  ref,
) async {
  final session = await ref.watch(activeFocusSessionProvider.future);
  if (session?.id == null) return [];
  final db = ref.read(databaseHelperProvider);
  return db.getQuestsInSession(session!.id!);
});

/// ตรวจสอบว่าเควสต์ที่มี ID นี้ กำลังถูกจับเวลา/โฟกัสอยู่ในเซสชันปัจจุบันหรือไม่
final isQuestFocusingProvider = Provider.family<bool, int>((ref, questId) {
  final session = ref.watch(activeFocusSessionProvider).valueOrNull;
  if (session == null) return false;
  final timers = ref.watch(activeQuestTimersProvider).valueOrNull ?? const [];
  return timers.any((t) => t.questId == questId && t.remainingSeconds > 0);
});
