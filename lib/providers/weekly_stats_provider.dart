import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quest_model.dart';
import '../models/quest_enums.dart';
import 'core_providers.dart';

/// สถิติรายวันสำหรับกราฟแท่ง
class DailyStatEntry {
  final DateTime date;
  final int completedCount;
  final int totalExpEarned;
  final Map<QuestCategory, int> countByCategory;

  const DailyStatEntry({
    required this.date,
    required this.completedCount,
    required this.totalExpEarned,
    required this.countByCategory,
  });

  int get completedQuestsCount => completedCount;
  String get dateLabel => '${date.day}/${date.month}';
}

final weeklyStatsProvider =
    FutureProvider<List<DailyStatEntry>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final quests = await db.getCompletedQuestsBetween(from, to);

  // group by day
  final Map<String, List<QuestModel>> byDay = {};
  for (var i = 0; i < 7; i++) {
    final d = from.add(Duration(days: i));
    byDay[_dayKey(d)] = [];
  }
  for (final q in quests) {
    if (q.completedAt == null) continue;
    final d = DateTime.parse(q.completedAt!);
    final key = _dayKey(d);
    byDay[key]?.add(q);
  }

  return byDay.entries.map((entry) {
    final date = DateTime.parse(entry.key);
    final dayQuests = entry.value;
    final countByCategory = <QuestCategory, int>{};
    var totalExp = 0;
    for (final q in dayQuests) {
      countByCategory[q.category] = (countByCategory[q.category] ?? 0) + 1;
      totalExp += q.awardedExp ?? q.expReward;
    }
    return DailyStatEntry(
      date: date,
      completedCount: dayQuests.length,
      totalExpEarned: totalExp,
      countByCategory: countByCategory,
    );
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
