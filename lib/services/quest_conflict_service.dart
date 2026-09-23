import '../models/quest_model.dart';
import '../models/quest_enums.dart';

/// ผลการตรวจ conflict ของคู่เควส
class ConflictResult {
  final bool hasConflict;
  final String? reason;
  const ConflictResult({required this.hasConflict, this.reason});
  static const none = ConflictResult(hasConflict: false);
}

/// QuestConflictService — Conflict Resolution Engine
/// ตรวจว่าเควส 2 อัน (หรือมากกว่า) ทำพร้อมกันได้ไหมตาม activity_type rules
class QuestConflictService {
  const QuestConflictService();

  // คู่ activity type ที่ขัดแย้งกันอย่างรุนแรง (unordered pairs)
  static const List<({ActivityType a, ActivityType b, String reason})> _severeConflicts = [
    (
      a: ActivityType.physicalHeavy,
      b: ActivityType.stillness,
      reason: 'ออกกำลังกายหนักและการนั่งสมาธิทำพร้อมกันไม่ได้',
    ),
  ];

  /// ตรวจว่า [candidate] ขัดแย้งกับเควสใดใน [selected] หรือไม่
  ConflictResult canAddToSelection(
    List<QuestModel> selected,
    QuestModel candidate,
  ) {
    for (final existing in selected) {
      final result = checkPair(existing.activityType, candidate.activityType);
      if (result.hasConflict) return result;
    }
    return ConflictResult.none;
  }

  /// ตรวจคู่ activity type โดยตรง
  ConflictResult checkPair(ActivityType a, ActivityType b) {
    for (final rule in _severeConflicts) {
      if ((rule.a == a && rule.b == b) || (rule.a == b && rule.b == a)) {
        return ConflictResult(hasConflict: true, reason: rule.reason);
      }
    }
    return ConflictResult.none;
  }

  /// คืน Set ของ quest id ที่ต้อง disable จาก [candidates]
  /// เพราะขัดแย้งกับอย่างน้อยหนึ่งเควสใน [selected]
  Set<int> getBlockedQuestIds(
    List<QuestModel> selected,
    List<QuestModel> candidates,
  ) {
    final blocked = <int>{};
    for (final candidate in candidates) {
      if (selected.any((s) => s.id == candidate.id)) continue;
      if (canAddToSelection(selected, candidate).hasConflict) {
        if (candidate.id != null) blocked.add(candidate.id!);
      }
    }
    return blocked;
  }
}
