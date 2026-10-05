import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/quest_model.dart';
import '../models/quest_enums.dart';
import 'core_providers.dart';

/// สถิติรายวันสำหรับกราฟแท่ง
class DailyStatEntry {
  final DateTime date;
  final int completedCount;
  final int totalExpEarned;
  final int focusMinutes;
  final Map<QuestCategory, int> countByCategory;

  const DailyStatEntry({
    required this.date,
    required this.completedCount,
    required this.totalExpEarned,
    required this.focusMinutes,
    required this.countByCategory,
  });

  int get completedQuestsCount => completedCount;
  String get dateLabel => '${date.day}/${date.month}';
}

class HeroStats {
  final int completedQuests;
  final int totalQuests;
  final int focusMinutes;
  final int totalExpEarned;
  final int bossesDefeated;

  const HeroStats({
    required this.completedQuests,
    required this.totalQuests,
    required this.focusMinutes,
    required this.totalExpEarned,
    required this.bossesDefeated,
  });

  int get successRate =>
      totalQuests == 0 ? 0 : ((completedQuests / totalQuests) * 100).round();
}

enum QuestActivityKind { checkIn, completed }

class QuestActivity {
  final QuestModel quest;
  final DateTime occurredAt;
  final QuestActivityKind kind;

  const QuestActivity({
    required this.quest,
    required this.occurredAt,
    required this.kind,
  });
}

final heroStatsProvider = FutureProvider<HeroStats>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final quests = await db.getQuests();
  final completed = quests
      .where((quest) => quest.isCompleted && !quest.isCampaignFailed)
      .toList();
  final checkinSummary = await db.getHabitCheckinSummary();
  final successfulQuestIds = <int>{
    ...checkinSummary.questIds,
    for (final quest in completed)
      if (quest.id != null) quest.id!,
  };
  final completedCampaigns = completed.where((quest) => quest.isCampaign);
  return HeroStats(
    completedQuests: successfulQuestIds.length,
    totalQuests: quests.length,
    focusMinutes:
        checkinSummary.focusMinutes +
        completed
            .where(
              (quest) =>
                  quest.goalType == QuestGoalType.focus && !quest.isCampaign,
            )
            .fold(0, (total, quest) => total + quest.estimatedMinutes),
    totalExpEarned: completed.fold(
      0,
      (total, quest) => total + (quest.awardedExp ?? quest.expReward),
    ),
    bossesDefeated: completedCampaigns.fold(
      0,
      (total, campaign) => total + ((campaign.habitTargetDays! - 1) ~/ 5) + 1,
    ),
  );
});

final recentQuestActivitiesProvider = FutureProvider<List<QuestActivity>>((
  ref,
) async {
  final activities = await _loadQuestActivities(
    ref.read(databaseHelperProvider),
    limitPerSource: 15,
    newestFirst: true,
  );
  return activities.reversed.take(15).toList();
});

final weeklyStatsProvider = FutureProvider<List<DailyStatEntry>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(Duration(days: today.weekday - 1));
  final to = from
      .add(const Duration(days: 7))
      .subtract(const Duration(microseconds: 1));

  final activities = await _loadQuestActivities(db, from: from, to: to);

  // group by day
  final Map<String, List<QuestActivity>> byDay = {};
  for (var i = 0; i < 7; i++) {
    final d = from.add(Duration(days: i));
    byDay[_dayKey(d)] = [];
  }
  for (final activity in activities) {
    final key = _dayKey(activity.occurredAt);
    byDay[key]?.add(activity);
  }

  return byDay.entries.map((entry) {
    final date = DateTime.parse(entry.key);
    final dayActivities = entry.value;
    final countByCategory = <QuestCategory, int>{};
    var totalExp = 0;
    var focusMinutes = 0;
    for (final activity in dayActivities) {
      final q = activity.quest;
      countByCategory[q.category] = (countByCategory[q.category] ?? 0) + 1;
      if (activity.kind == QuestActivityKind.completed) {
        totalExp += q.awardedExp ?? q.expReward;
      }
      if (q.goalType == QuestGoalType.focus) {
        focusMinutes += q.estimatedMinutes;
      }
    }
    return DailyStatEntry(
      date: date,
      completedCount: dayActivities.length,
      totalExpEarned: totalExp,
      focusMinutes: focusMinutes,
      countByCategory: countByCategory,
    );
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
});

Future<List<QuestActivity>> _loadQuestActivities(
  DatabaseHelper db, {
  DateTime? from,
  DateTime? to,
  int? limitPerSource,
  bool newestFirst = false,
}) async {
  final completedQuests = from != null && to != null
      ? await db.getCompletedQuestsBetween(from, to)
      : limitPerSource != null
      ? await db.getRecentCompletedQuests(limit: limitPerSource)
      : await db.getQuests(isCompleted: true);
  final activities = <QuestActivity>[];
  final completionKeys = <String>{};

  for (final quest in completedQuests) {
    if (quest.isCampaignFailed || quest.completedAt == null) continue;
    final completedAt = DateTime.parse(quest.completedAt!);
    completionKeys.add(_activityKey(quest, completedAt));
    activities.add(
      QuestActivity(
        quest: quest,
        occurredAt: completedAt,
        kind: QuestActivityKind.completed,
      ),
    );
  }

  final checkins = await db.getHabitCheckins(
    from: from,
    to: to,
    limit: limitPerSource,
    newestFirst: newestFirst,
  );
  for (final checkin in checkins) {
    if (completionKeys.contains(
      _activityKey(checkin.quest, checkin.checkedInAt),
    )) {
      continue;
    }
    activities.add(
      QuestActivity(
        quest: checkin.quest,
        occurredAt: checkin.checkedInAt,
        kind: QuestActivityKind.checkIn,
      ),
    );
  }

  activities.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  return activities;
}

String _activityKey(QuestModel quest, DateTime date) =>
    '${quest.id}:${_dayKey(date)}';

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
