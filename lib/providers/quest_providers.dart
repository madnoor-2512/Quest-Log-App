import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quest_model.dart';
import '../models/sub_task_model.dart';
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

  Future<void> deleteQuest(int questId) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteQuest(questId);
    ref.invalidate(questListProvider);
    // เควสที่ลบอาจเคยสำเร็จไปแล้ว (นับอยู่ในกราฟ 7 วัน) จึงต้อง invalidate
    // weeklyStatsProvider ด้วย ไม่งั้นกราฟจะค้างนับเควสที่ถูกลบไปแล้ว
    ref.invalidate(weeklyStatsProvider);
  }

  Future<({int exp, int gold, bool wasCapped})> completeQuest(
    int questId,
  ) async {
    final db = ref.read(databaseHelperProvider);
    final calculator = ref.read(rewardCalculatorProvider);

    // ดึงเควสมาก่อน (ยังไม่ mark complete) เพื่อเอา exp_reward/gold_reward
    // เป็น "ฐาน" สำหรับคำนวณ — ยังไม่เขียนอะไรลง DB ตรงนี้
    final quest = await db.getQuestById(questId);
    if (quest == null) {
      throw StateError('Quest $questId not found.');
    }

    await ref.read(userProvider.notifier).touchDailyStreak();
    final streakCount = ref.read(userProvider).valueOrNull?.streakCount ?? 0;

    // นับยอดที่ "ได้รับจริง" ของวันนี้ (ไม่รวมเควสนี้ เพราะยังไม่ complete)
    final todayTotals = await db.getTodayEarnedTotals();

    final result = calculator.resolveQuestCompletionReward(
      baseExp: quest.expReward,
      baseGold: quest.goldReward,
      streakCount: streakCount,
      alreadyEarnedExpToday: todayTotals['exp'] ?? 0,
      alreadyEarnedGoldToday: todayTotals['gold'] ?? 0,
    );

    // เขียน DB ครั้งเดียว: mark complete พร้อมบันทึกยอดที่ได้รับจริง
    // ไปด้วยกัน กัน race condition ระหว่าง 2 การเขียน
    await db.completeQuest(
      questId,
      awardedExp: result.awardedExp,
      awardedGold: result.awardedGold,
    );

    await ref
        .read(userProvider.notifier)
        .addExpAndGold(exp: result.awardedExp, gold: result.awardedGold);

    ref.invalidate(questListProvider);
    // Dashboard ใช้ IndexedStack ทำให้ StatsScreen ถูก mount ค้างไว้ตลอด —
    // ถ้าไม่ invalidate ตรงนี้ กราฟ 7 วันใน Stats จะไม่อัปเดตหลังทำเควส
    // สำเร็จ จนกว่าจะ hot reload/restart แอป
    ref.invalidate(weeklyStatsProvider);

    return (
      exp: result.awardedExp,
      gold: result.awardedGold,
      wasCapped: result.wasCapped,
    );
  }
}
