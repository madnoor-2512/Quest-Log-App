import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement_model.dart';
import '../models/quest_model.dart';
import '../models/quest_enums.dart';
import '../models/sub_task_model.dart';
import '../services/gamification_config.dart';
import 'achievements_providers.dart';
import 'core_providers.dart';
import 'user_provider.dart';
import 'weekly_stats_provider.dart';

class QuestFilter {
  final String? category;
  final bool? isCompleted;

  const QuestFilter({this.category, this.isCompleted});

  static const all = QuestFilter();
  static const completed = QuestFilter(isCompleted: true);
  static const main = QuestFilter(category: 'MAIN', isCompleted: false);
  static const side = QuestFilter(category: 'SIDE', isCompleted: false);
  static const daily = QuestFilter(category: 'DAILY', isCompleted: false);
  static const incomplete = QuestFilter(isCompleted: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestFilter &&
          other.category == category &&
          other.isCompleted == isCompleted);

  @override
  int get hashCode => Object.hash(category, isCompleted);
}

final questListProvider =
    AsyncNotifierProvider.family<
      QuestListNotifier,
      List<QuestModel>,
      QuestFilter
    >(QuestListNotifier.new);

class QuestListNotifier
    extends FamilyAsyncNotifier<List<QuestModel>, QuestFilter> {
  @override
  Future<List<QuestModel>> build(QuestFilter arg) async {
    final db = ref.read(databaseHelperProvider);
    return db.getQuests(category: arg.category, isCompleted: arg.isCompleted);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(databaseHelperProvider)
          .getQuests(category: arg.category, isCompleted: arg.isCompleted),
    );
  }
}

final subTasksProvider =
    AsyncNotifierProvider.family<SubTasksNotifier, List<SubTaskModel>, int>(
      SubTasksNotifier.new,
    );

class SubTasksNotifier extends FamilyAsyncNotifier<List<SubTaskModel>, int> {
  @override
  Future<List<SubTaskModel>> build(int questId) async {
    final db = ref.read(databaseHelperProvider);
    return db.getSubTasksForQuest(questId);
  }

  Future<void> toggleSubTask(SubTaskModel subTask) async {
    final db = ref.read(databaseHelperProvider);
    await db.updateSubTask(subTask.copyWith(isCompleted: !subTask.isCompleted));
    state = await AsyncValue.guard(() => db.getSubTasksForQuest(arg));
  }
}

final questActionsProvider = AsyncNotifierProvider<QuestActionsNotifier, void>(
  QuestActionsNotifier.new,
);

class QuestActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int> addQuest(
    QuestModel quest, {
    List<String> subTaskTitles = const [],
  }) async {
    final db = ref.read(databaseHelperProvider);
    final id = await db.insertQuest(quest);
    // เพิ่ม sub-tasks (ถ้ามี) หลังจากรู้ id ของเควสที่เพิ่งสร้างแล้ว
    for (final title in subTaskTitles) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) continue;
      await db.insertSubTask(SubTaskModel(questId: id, title: trimmed));
    }
    ref.invalidate(questListProvider);
    return id;
  }

  Future<({int exp, int gold, int day, bool completed})> checkInHabit(
    int questId, {
    DateTime? now,
  }) async {
    final db = ref.read(databaseHelperProvider);
    final quest = await db.getQuestById(questId);
    if (quest == null || quest.goalType != QuestGoalType.dailyHabit) {
      throw StateError('This quest is not a daily habit.');
    }
    final current = now ?? DateTime.now();
    final start = quest.habitStartMinute ?? 0;
    final end = quest.habitEndMinute ?? 1439;
    final minute = current.hour * 60 + current.minute;
    if (minute < start || minute > end) {
      throw StateError('อยู่นอกช่วงเวลาเช็กอินของเควสต์นี้');
    }
    if (await db.hasHabitCheckinToday(questId, now: current)) {
      throw StateError('เช็กอินเควสต์นี้วันนี้ไปแล้ว');
    }
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) throw StateError('ไม่มีผู้ใช้ที่กำลังใช้งาน');
    final count = await db.getHabitCheckinCount(questId);
    final targetDays = quest.habitTargetDays ?? 30;
    final result = ref.read(rewardCalculatorProvider).resolveQuestCompletionReward(
      baseExp: quest.expReward,
      baseGold: quest.goldReward,
      streakCount: user.streakCount,
      alreadyEarnedExpToday: (await db.getTodayEarnedTotals())['exp'] ?? 0,
      alreadyEarnedGoldToday: (await db.getTodayEarnedTotals())['gold'] ?? 0,
      hasRpgClass: user.rpgClass != null,
    );
    final completed = count + 1 >= targetDays;
    final updatedUser = user.withRewards(
      exp: result.awardedExp,
      gold: result.awardedGold,
    );
    await db.checkInHabitAndUpdateUser(
      questId: questId,
      updatedUser: updatedUser,
      now: current,
      completeQuest: completed,
      awardedExp: result.awardedExp,
      awardedGold: result.awardedGold,
    );
    await ref.read(userProvider.notifier).refresh();
    ref.invalidate(questListProvider);
    ref.invalidate(weeklyStatsProvider);
    return (
      exp: result.awardedExp,
      gold: result.awardedGold,
      day: count + 1,
      completed: completed,
    );
  }

  Future<void> deleteQuest(int questId) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteQuest(questId);
    ref.invalidate(questListProvider);
    // เควสที่ลบอาจเคยสำเร็จไปแล้ว (นับอยู่ในกราฟ 7 วัน) จึงต้อง invalidate
    // weeklyStatsProvider ด้วย ไม่งั้นกราฟจะค้างนับเควสที่ถูกลบไปแล้ว
    ref.invalidate(weeklyStatsProvider);
  }

  Future<
    ({int exp, int gold, bool wasCapped, List<AchievementDef> newAchievements})
  >
  completeQuest(
    int questId, {
    bool isConcurrent = false,
    bool fromFocus = false,
    double focusCompletionRatio = 1.0,
  }) async {
    final db = ref.read(databaseHelperProvider);
    final calculator = ref.read(rewardCalculatorProvider);

    // ดึงเควสมาก่อน (ยังไม่ mark complete) เพื่อเอา exp_reward/gold_reward
    // เป็น "ฐาน" สำหรับคำนวณ — ยังไม่เขียนอะไรลง DB ตรงนี้
    final quest = await db.getQuestById(questId);
    if (quest == null) {
      throw StateError('Quest $questId not found.');
    }
    if (quest.isCompleted) {
      throw StateError('Quest $questId is already completed.');
    }
    if (quest.goalType == QuestGoalType.dailyHabit) {
      throw StateError('Daily Habit ต้องใช้ปุ่ม Check-in ตามช่วงเวลาที่กำหนด');
    }
    if (quest.estimatedMinutes > 0 &&
        (!fromFocus ||
            focusCompletionRatio <
                GamificationConfig.minimumFocusCompletionRatio)) {
      throw StateError(
        'เควสต์นี้ต้องทำผ่าน Focus Timer อย่างน้อย '
        '${(GamificationConfig.minimumFocusCompletionRatio * 100).round()}% '
        'ก่อนรับรางวัล',
      );
    }

    await ref.read(userProvider.notifier).touchDailyStreak();
    final user = ref.read(userProvider).valueOrNull;
    final streakCount = user?.streakCount ?? 0;

    // นับยอดที่ "ได้รับจริง" ของวันนี้ (ไม่รวมเควสนี้ เพราะยังไม่ complete)
    final todayTotals = await db.getTodayEarnedTotals();

    final result = calculator.resolveQuestCompletionReward(
      baseExp: quest.expReward,
      baseGold: quest.goldReward,
      streakCount: streakCount,
      alreadyEarnedExpToday: todayTotals['exp'] ?? 0,
      alreadyEarnedGoldToday: todayTotals['gold'] ?? 0,
      hasRpgClass: user?.rpgClass != null,
      isConcurrent: isConcurrent,
    );

    if (user == null) {
      throw StateError('Cannot complete a quest without an active user.');
    }
    final updatedUser = user.withRewards(
      exp: result.awardedExp,
      gold: result.awardedGold,
    );

    // Mark the quest and award the user's rewards in one transaction.
    await db.completeQuestAndUpdateUser(
      questId: questId,
      awardedExp: result.awardedExp,
      awardedGold: result.awardedGold,
      updatedUser: updatedUser,
    );
    await ref.read(userProvider.notifier).refresh();

    ref.invalidate(questListProvider);
    // Dashboard ใช้ IndexedStack ทำให้ StatsScreen ถูก mount ค้างไว้ตลอด —
    // ถ้าไม่ invalidate ตรงนี้ กราฟ 7 วันใน Stats จะไม่อัปเดตหลังทำเควส
    // สำเร็จ จนกว่าจะ hot reload/restart แอป
    ref.invalidate(weeklyStatsProvider);

    // เช็ค Achievement หลังทำเควสสำเร็จทุกครั้ง — ต้องนับจำนวนเควสที่
    // สำเร็จสะสม "หลัง" mark complete แล้ว (รวมอันนี้ด้วย) ถึงจะถูกต้อง
    final completedCount = await db.getCompletedQuestsCount();
    final latestStreak =
        ref.read(userProvider).valueOrNull?.streakCount ?? streakCount;
    final newAchievements = await ref
        .read(unlockedAchievementCodesProvider.notifier)
        .checkAndUnlock(
          streakDays: latestStreak,
          questsCompleted: completedCount,
        );

    return (
      exp: result.awardedExp,
      gold: result.awardedGold,
      wasCapped: result.wasCapped,
      newAchievements: newAchievements,
    );
  }
}
