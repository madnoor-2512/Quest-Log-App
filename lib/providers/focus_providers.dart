import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quest_model.dart';
import '../models/focus_session_model.dart';
import '../models/reward_model.dart';
import 'core_providers.dart';

final focusSelectionProvider =
    NotifierProvider<FocusSelectionNotifier, List<QuestModel>>(
      FocusSelectionNotifier.new,
    );

class FocusSelectionNotifier extends Notifier<List<QuestModel>> {
  @override
  List<QuestModel> build() => const [];

  void add(QuestModel quest) {
    if (state.any((q) => q.id == quest.id)) return;
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

final blockedQuestIdsProvider = Provider.family<Set<int>, List<QuestModel>>((
  ref,
  candidates,
) {
  final selected = ref.watch(focusSelectionProvider);
  final conflictService = ref.watch(questConflictServiceProvider);
  return conflictService.getBlockedQuestIds(selected, candidates);
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

    final db = ref.read(databaseHelperProvider);

    // Equipment bonus จริง — ถ้ามีของสวมใส่อยู่ที่ effectType เป็น
    // focusTimeBonusPercent ให้บวกเวลาที่ได้เพิ่มเข้าไปตอนเริ่ม session
    // เลย (เช่นสวม "หูฟัง Lo-Fi +10% Focus Time" -> เซสชัน 25 นาที
    // กลายเป็น 27.5 นาทีจริง)
    var finalDurationSeconds = targetDurationSeconds;
    final equipped = await db.getEquippedEquipment();
    if (equipped != null &&
        equipped.effectType == ItemEffectType.focusTimeBonusPercent &&
        equipped.effectValue != null) {
      finalDurationSeconds =
          (targetDurationSeconds * (1 + equipped.effectValue!)).round();
    }

    final startedAt = DateTime.now().toIso8601String();

    final sessionId = await db.startFocusSession(
      startedAt: startedAt,
      targetDuration: finalDurationSeconds,
      questIds: selected.map((q) => q.id!).toList(),
    );

    ref.read(focusSelectionProvider.notifier).clear();
    state = AsyncValue.data(
      FocusSessionModel(
        id: sessionId,
        startedAt: startedAt,
        targetDuration: finalDurationSeconds,
      ),
    );
    ref.invalidate(activeSessionQuestsProvider);
  }

  /// บวกเวลาเพิ่มให้ session ที่กำลัง active อยู่ทันที (ใช้จากไอเทม
  /// consumable "คัมภีร์ยืดเวลา" effectType: extendFocusMinutes) — แก้ทั้ง
  /// DB (target_duration) และ state ในตัว
  Future<bool> extendActiveSession(int extraMinutes) async {
    final session = state.valueOrNull;
    if (session?.id == null) return false;
    final db = ref.read(databaseHelperProvider);
    final newDuration = session!.targetDuration + (extraMinutes * 60);
    await db.updateFocusSessionDuration(session.id!, newDuration);
    state = AsyncValue.data(session.copyWith(targetDuration: newDuration));
    return true;
  }

  Future<void> end() async {
    final session = state.valueOrNull;
    if (session?.id == null) return;
    await ref.read(databaseHelperProvider).endFocusSession(session!.id!);
    state = const AsyncValue.data(null);
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
