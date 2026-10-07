import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement_model.dart';
import '../models/quest_model.dart';
import '../models/quest_enums.dart';
import '../models/sub_task_model.dart';
import '../services/gamification_config.dart';
import 'achievements_providers.dart';
import 'core_providers.dart';
import 'focus_providers.dart';
import 'user_provider.dart';
import 'weekly_stats_provider.dart';

class QuestFilter {
  final String? category;
  final bool? isCompleted;
  final bool excludeCheckedInToday;

  const QuestFilter({
    this.category,
    this.isCompleted,
    this.excludeCheckedInToday = false,
  });

  static const all = QuestFilter();
  static const completed = QuestFilter(isCompleted: true);
  static const main = QuestFilter(category: 'MAIN', isCompleted: false);
  static const side = QuestFilter(category: 'SIDE', isCompleted: false);
  static const daily = QuestFilter(
    category: 'DAILY',
    isCompleted: false,
    excludeCheckedInToday: true,
  );
  static const incomplete = QuestFilter(isCompleted: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestFilter &&
          other.category == category &&
          other.isCompleted == isCompleted &&
          other.excludeCheckedInToday == excludeCheckedInToday);

  @override
  int get hashCode => Object.hash(category, isCompleted, excludeCheckedInToday);
}

final questListProvider =
    AsyncNotifierProvider.family<
      QuestListNotifier,
      List<QuestModel>,
      QuestFilter
    >(QuestListNotifier.new);

final campaignCheckinCountProvider = FutureProvider.family<int, int>((
  ref,
  questId,
) async {
  ref.watch(questListProvider(QuestFilter.all));
  return ref.read(databaseHelperProvider).getHabitCheckinCount(questId);
});

class QuestListNotifier
    extends FamilyAsyncNotifier<List<QuestModel>, QuestFilter> {
  @override
  Future<List<QuestModel>> build(QuestFilter arg) async {
    final db = ref.read(databaseHelperProvider);
    return db.getQuests(
      category: arg.category,
      isCompleted: arg.isCompleted,
      excludeCheckedInToday: arg.excludeCheckedInToday,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(databaseHelperProvider)
          .getQuests(
            category: arg.category,
            isCompleted: arg.isCompleted,
            excludeCheckedInToday: arg.excludeCheckedInToday,
          ),
    );
  }
}

/// เควสต์ที่ทำสำเร็จวันนี้ — ใช้แสดงในหน้า Stats ด้วยสถานะขีดฆ่า +
/// ไอคอนเครื่องหมายถูกสีเขียว + ตัวเลขโบนัส EXP/Gold ที่ได้รับ
final todayCompletedQuestsProvider = FutureProvider<List<QuestModel>>((
  ref,
) async {
  // invalidate เมื่อ questListProvider เปลี่ยน (เช่น มีเควสใหม่สำเร็จ)
  ref.watch(questListProvider(QuestFilter.all));
  final db = ref.read(databaseHelperProvider);
  return db.getTodayCompletedQuests();
});

/// กรองเฉพาะเควสต์ที่ความถี่ (Frequency) ตรงกับวันปัจจุบัน — ใช้แสดง
/// จำนวนรวมที่ส่วนหัวของกระดาน เพื่อให้ผู้เล่นรู้ว่าวันนี้มีกี่ภารกิจ
/// ที่ต้องทำจริง (ไม่นับเควสต์ที่ไม่ตรงวัน เช่น เลือกทำเฉพาะ จ-ศ แต่วันนี้
/// เป็นเสาร์)
final todayFrequencyQuestsProvider = FutureProvider<List<QuestModel>>((
  ref,
) async {
  ref.watch(questListProvider(QuestFilter.all));
  final db = ref.read(databaseHelperProvider);
  final allIncomplete = await db.getQuests(
    isCompleted: false,
    excludeCheckedInToday: true,
  );
  final todayWeekday = DateTime.now().weekday; // ISO: 1=จันทร์ ... 7=อาทิตย์
  return allIncomplete.where((q) {
    final allowed = q.effectiveHabitWeekdays;
    // เควสต์ที่ไม่มีกำหนดวัน (allowed ว่าง) ถือว่าทำได้ทุกวัน
    return allowed.isEmpty || allowed.contains(todayWeekday);
  }).toList();
});

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
    ref.invalidate(heroStatsProvider);
    ref.invalidate(recentQuestActivitiesProvider);
    return id;
  }

  Future<void> updateQuest(QuestModel quest) async {
    final db = ref.read(databaseHelperProvider);
    // หากเควสต์ที่กำลังแก้ไขมี Timer กำลังทำงานอยู่ ให้ invalidate ข้อมูลเซสชันเพื่อให้ซิงก์
    final activeTimers =
        ref.read(activeQuestTimersProvider).valueOrNull ?? const [];
    final isFocused = activeTimers.any(
      (t) => t.questId == quest.id && t.remainingSeconds > 0,
    );
    if (isFocused) {
      ref.invalidate(activeSessionQuestsProvider);
    }
    await db.updateQuest(quest);
    ref.invalidate(questListProvider);
    ref.invalidate(activeSessionQuestsProvider);
    ref.invalidate(heroStatsProvider);
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(recentQuestActivitiesProvider);
  }

  Future<
    ({
      int exp,
      int gold,
      int day,
      bool completed,
      bool isMiniBoss,
      bool isFinalBoss,
      int bossBonusExp,
      int bossBonusGold,
      int bossBonusGems,
    })
  >
  checkInHabit(
    int questId, {
    DateTime? now,
    bool fromFocusTimer = false,
  }) async {
    final db = ref.read(databaseHelperProvider);
    final quest = await db.getQuestById(questId);
    final isDailyHabit = quest?.goalType == QuestGoalType.dailyHabit;
    final isFocusCampaign =
        fromFocusTimer &&
        quest?.goalType == QuestGoalType.focus &&
        quest!.isCampaign;
    if (quest == null || (!isDailyHabit && !isFocusCampaign)) {
      throw StateError('This quest is not a daily habit.');
    }
    final current = now ?? DateTime.now();
    final start = quest.habitStartMinute ?? 0;
    final end = quest.habitEndMinute ?? 1439;
    final minute = current.hour * 60 + current.minute;
    if (minute < start || minute > end) {
      throw StateError('อยู่นอกช่วงเวลาเช็กอินของเควสต์นี้');
    }
    // ความถี่รายสัปดาห์ (ทุกวัน / จันทร์-ศุกร์ / กำหนดเอง) — ว่างเปล่า
    // (เควสต์เก่าก่อนมีฟีเจอร์นี้ หรือกำหนดเองแล้วไม่ได้เลือกวันเลย)
    // ถือว่าไม่จำกัดวัน เพื่อไม่ให้เควสต์เก่าเช็กอินไม่ได้
    final allowedWeekdays = quest.effectiveHabitWeekdays;
    if (allowedWeekdays.isNotEmpty &&
        !allowedWeekdays.contains(current.weekday)) {
      throw StateError('วันนี้ไม่ใช่วันที่กำหนดไว้สำหรับเควสต์นี้');
    }
    if (await db.hasHabitCheckinToday(questId, now: current)) {
      throw StateError('เช็กอินเควสต์นี้วันนี้ไปแล้ว');
    }
    await ref.read(userProvider.notifier).touchDailyStreak(now: current);
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) throw StateError('ไม่มีผู้ใช้ที่กำลังใช้งาน');
    final count = await db.getHabitCheckinCount(questId);
    final targetDays = quest.habitTargetDays;
    final result = ref
        .read(rewardCalculatorProvider)
        .resolveQuestCompletionReward(
          baseExp: quest.expReward,
          baseGold: quest.goldReward,
          streakCount: user.streakCount,
          alreadyEarnedExpToday: (await db.getTodayEarnedTotals())['exp'] ?? 0,
          alreadyEarnedGoldToday:
              (await db.getTodayEarnedTotals())['gold'] ?? 0,
          hasRpgClass: user.rpgClass != null,
        );
    final completed = targetDays != null && count + 1 >= targetDays;

    // Boss Logic
    final day = count + 1;
    final isFinalBoss = completed;
    final isMiniBoss = targetDays != null && day % 5 == 0 && !isFinalBoss;

    int bossBonusExp = 0;
    int bossBonusGold = 0;
    int bossBonusGems = 0;
    final random = math.Random();

    if (isFinalBoss) {
      bossBonusGems = ref
          .read(rewardCalculatorProvider)
          .calculateBossDiamondReward(isFinalBoss: true);
      if (random.nextBool()) {
        bossBonusExp = 200 + random.nextInt(201);
      } else {
        bossBonusGold = 100 + random.nextInt(101);
      }
    } else if (isMiniBoss) {
      bossBonusGems = ref
          .read(rewardCalculatorProvider)
          .calculateBossDiamondReward(isMiniBoss: true);
      if (random.nextBool()) {
        bossBonusExp = 50 + random.nextInt(51);
      } else {
        bossBonusGold = 25 + random.nextInt(26);
      }
    }

    final totalExp = result.awardedExp + bossBonusExp;
    final totalGold = result.awardedGold + bossBonusGold;

    // ระดับความยากของเควสต์ทันใจมีผลต่อ HP ที่ฟื้นฟูด้วย เหมือน Focus
    // Quest (ดูเหตุผลที่ RewardCalculatorService.estimateHpGain)
    final hpGain = ref
        .read(rewardCalculatorProvider)
        .estimateHpGain(
          difficulty: quest.difficulty,
          streakBoost: user.streakCount >= 3,
        );
    final updatedUser = user.withRewards(
      exp: totalExp,
      gold: totalGold,
      hpGain: hpGain,
      bonusGems: bossBonusGems,
    );
    await db.checkInHabitAndUpdateUser(
      questId: questId,
      updatedUser: updatedUser,
      now: current,
      completeQuest: completed,
      awardedExp: totalExp,
      awardedGold: totalGold,
    );
    await ref.read(userProvider.notifier).refresh();
    ref.invalidate(questListProvider);
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(heroStatsProvider);
    ref.invalidate(recentQuestActivitiesProvider);
    return (
      exp: totalExp,
      gold: totalGold,
      day: day,
      completed: completed,
      isMiniBoss: isMiniBoss,
      isFinalBoss: isFinalBoss,
      bossBonusExp: bossBonusExp,
      bossBonusGold: bossBonusGold,
      bossBonusGems: bossBonusGems,
    );
  }

  Future<void> deleteQuest(int questId) async {
    final db = ref.read(databaseHelperProvider);
    // ตรวจสอบระดับ Provider: หากเควสต์ที่กำลังจะถูกลบ มี Timer กำลังวิ่งอยู่
    // ให้ระบบทำการ Force Stop Timer ของเควสต์นั้นทันทีอย่างเงียบๆ (เพื่อไม่ให้แครช)
    // และทำโทษหัก HP ถือว่าเป็นการหลบหนีจากการต่อสู้
    final activeTimers =
        ref.read(activeQuestTimersProvider).valueOrNull ?? const [];
    final runningTimer = activeTimers
        .where((t) => t.questId == questId && t.remainingSeconds > 0)
        .firstOrNull;
    if (runningTimer != null) {
      await ref
          .read(activeQuestTimersProvider.notifier)
          .forceStopTimer(questId);
      final quest = await db.getQuestById(questId);
      final damage = (quest != null && quest.difficulty > 0)
          ? quest.difficulty * 8
          : 15;
      await ref.read(userProvider.notifier).applyHpDamage(damage);
    }

    await db.deleteQuest(questId);
    ref.invalidate(questListProvider);
    ref.invalidate(activeSessionQuestsProvider);
    ref.invalidate(activeQuestTimersProvider);
    // เควสที่ลบอาจเคยสำเร็จไปแล้ว (นับอยู่ในกราฟ 7 วัน) จึงต้อง invalidate
    // weeklyStatsProvider ด้วย ไม่งั้นกราฟจะค้างนับเควสที่ถูกลบไปแล้ว
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(heroStatsProvider);
    ref.invalidate(recentQuestActivitiesProvider);
  }

  Future<int> failOrAbandonQuest(int questId) async {
    final db = ref.read(databaseHelperProvider);
    final quest = await db.getQuestById(questId);
    if (quest == null) return 0;
    final damage = quest.difficulty * 8;
    await ref.read(userProvider.notifier).applyHpDamage(damage);
    return damage;
  }

  Future<
    ({
      int exp,
      int gold,
      int hpGained,
      int overflowGold,
      bool wasCapped,
      List<AchievementDef> newAchievements,
    })
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

    // คำนวณการฟื้นฟู HP ตามระดับความยากของเควสต์ + บัฟคนขยัน (Streak >= 3)
    final hpGain = calculator.estimateHpGain(
      difficulty: quest.difficulty,
      streakBoost: streakCount >= 3,
    );
    final overflowGold = (user.currentHp + hpGain > user.maxHp)
        ? (user.currentHp + hpGain) - user.maxHp
        : 0;

    final updatedUser = user.withRewards(
      exp: result.awardedExp,
      gold: result.awardedGold,
      hpGain: hpGain,
    );

    // Mark the quest and award the user's rewards in one transaction.
    await db.completeQuestAndUpdateUser(
      questId: questId,
      awardedExp: result.awardedExp,
      awardedGold: result.awardedGold + overflowGold,
      updatedUser: updatedUser,
    );
    await ref.read(userProvider.notifier).refresh();

    ref.invalidate(questListProvider);
    // Dashboard ใช้ IndexedStack ทำให้ StatsScreen ถูก mount ค้างไว้ตลอด —
    // ถ้าไม่ invalidate ตรงนี้ กราฟ 7 วันใน Stats จะไม่อัปเดตหลังทำเควส
    // สำเร็จ จนกว่าจะ hot reload/restart แอป
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(heroStatsProvider);
    ref.invalidate(recentQuestActivitiesProvider);

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
      gold: result.awardedGold + overflowGold,
      hpGained: hpGain,
      overflowGold: overflowGold,
      wasCapped: result.wasCapped,
      newAchievements: newAchievements,
    );
  }
}
