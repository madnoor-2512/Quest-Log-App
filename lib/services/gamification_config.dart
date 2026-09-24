import '../models/quest_enums.dart';

/// GamificationConfig — ค่าคงที่ทั้งหมดของระบบ gamification
/// ปรับสมดุลเกมได้จากไฟล์เดียว ไม่ต้องแก้ logic
class GamificationConfig {
  GamificationConfig._();

  // Base reward rate
  static const double baseExpPerMinute = 2.0;
  static const double goldToExpRatio = 0.5;

  // Minimums
  static const int minExpReward = 5;
  static const int minGoldReward = 2;

  // Difficulty multipliers (1–5)
  static const Map<int, double> difficultyMultipliers = {
    1: 0.8,
    2: 1.0,
    3: 1.3,
    4: 1.7,
    5: 2.2,
  };

  // Activity type multipliers
  static const Map<ActivityType, double> activityTypeMultipliers = {
    ActivityType.mental: 1.0,
    ActivityType.stillness: 1.1,
    ActivityType.audioOnly: 0.9,
    ActivityType.physicalHeavy: 1.2,
  };

  // EXP per sub-task
  static const double expPerSubTask = 3.0;

  // Duration-Difficulty Gatekeeper
  static const int gatekeeperDifficultyThreshold = 4; // difficulty >= 4
  static const int gatekeeperMinMinutes = 30; // must be >= 30 min

  // Daily Cap (Anti-Exploit)
  static const int dailyExpCap = 500;
  static const int dailyGoldCap = 250;

  // Streak Multiplier
  static const double streakBonusPerDay = 0.05; // 5% per day
  static const double maxStreakBonus = 1.0; // capped at +100%

  // RPG Class — โบนัส EXP จริงเมื่อเลือกสายแล้ว (เท่ากันทุกสาย)
  static const double rpgClassExpBonus = 0.15; // +15%

  // Concurrent focus — โบนัสเมื่อจัดการเควสต์ที่ทำพร้อมกันสำเร็จ
  static const double concurrentQuestBonus = 0.10; // +10%

  // Inventory — ขยายช่องคลังไอเทมด้วย Gold
  static const int inventoryExpandCost = 150; // Gold ต่อครั้ง
  static const int inventoryExpandAmount = 5; // +5 ช่องต่อครั้ง
}
