import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/models/quest_enums.dart';
import 'package:quest_log/models/quest_model.dart';
import 'package:quest_log/services/quest_conflict_service.dart';

void main() {
  const service = QuestConflictService();

  test('different pools can run together when one is background audio', () {
    expect(
      service
          .checkPair(ActivityType.physicalHeavy, ActivityType.audioOnly)
          .hasConflict,
      isFalse,
    );
  });

  test('physical activities in the same foreground pool conflict', () {
    expect(
      service
          .checkPair(ActivityType.stillness, ActivityType.physicalHeavy)
          .hasConflict,
      isTrue,
    );
    expect(
      service
          .checkPair(ActivityType.physicalHeavy, ActivityType.physicalHeavy)
          .hasConflict,
      isTrue,
    );
  });

  test('duplicate cognitive activities conflict', () {
    expect(
      service.checkPair(ActivityType.mental, ActivityType.mental).hasConflict,
      isTrue,
    );
  });

  test('different foreground pools can run together', () {
    expect(
      service
          .checkPair(ActivityType.stillness, ActivityType.mental)
          .hasConflict,
      isFalse,
    );
    expect(
      service
          .checkPair(ActivityType.physicalHeavy, ActivityType.mental)
          .hasConflict,
      isFalse,
    );
  });

  test('physical activities conflict with visual-focus quests', () {
    expect(
      service
          .checkPair(ActivityType.physicalHeavy, ActivityType.visual)
          .hasConflict,
      isTrue,
    );
    expect(
      service.checkPair(ActivityType.visual, ActivityType.mental).hasConflict,
      isFalse,
    );
  });

  test('background audio can overlap another audio quest', () {
    expect(
      service
          .checkPair(ActivityType.audioOnly, ActivityType.audioOnly)
          .hasConflict,
      isFalse,
    );
  });

  test('blocked quest ids follow the saved activity pool', () {
    final selected = QuestModel(
      id: 1,
      title: 'ซ้อมมวย',
      activityType: ActivityType.physicalHeavy,
      expReward: 0,
      goldReward: 0,
      createdAt: '2026-10-07',
    );
    final meditation = QuestModel(
      id: 2,
      title: 'นั่งสมาธิ',
      activityType: ActivityType.stillness,
      expReward: 0,
      goldReward: 0,
      createdAt: '2026-10-07',
    );
    final reading = QuestModel(
      id: 3,
      title: 'อ่านหนังสือ',
      activityType: ActivityType.visual,
      expReward: 0,
      goldReward: 0,
      createdAt: '2026-10-07',
    );
    final podcast = QuestModel(
      id: 4,
      title: 'ฟังพอดแคสต์',
      activityType: ActivityType.audioOnly,
      expReward: 0,
      goldReward: 0,
      createdAt: '2026-10-07',
    );
    final thinking = QuestModel(
      id: 5,
      title: 'คิดวางแผน',
      activityType: ActivityType.mental,
      expReward: 0,
      goldReward: 0,
      createdAt: '2026-10-07',
    );

    expect(
      service.getBlockedQuestIds(
        [selected],
        [selected, meditation, reading, podcast, thinking],
        maxParallelQuests: 2,
      ),
      {meditation.id, reading.id},
    );
  });

  test('visual activity type round-trips through the database value', () {
    expect(ActivityTypeX.fromDb('VISUAL'), ActivityType.visual);
    expect(ActivityType.visual.dbValue, 'VISUAL');
  });
}
