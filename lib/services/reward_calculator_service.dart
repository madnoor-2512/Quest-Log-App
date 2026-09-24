import 'dart:math';

import '../models/quest_enums.dart';
import 'gamification_config.dart';

class RewardCalculationResult {
  final bool isAllowed;
  final String? blockReason;
  final int expReward;
  final int goldReward;

  const RewardCalculationResult({
    required this.isAllowed,
    this.blockReason,
    this.expReward = 0,
    this.goldReward = 0,
  });

  factory RewardCalculationResult.blocked(String reason) =>
      RewardCalculationResult(isAllowed: false, blockReason: reason);
}

class StreakAdjustedReward {
  final int exp;
  final int gold;
  final double multiplierApplied;
  const StreakAdjustedReward({
    required this.exp,
    required this.gold,
    required this.multiplierApplied,
  });
}

class DailyCapResult {
  final int awardedExp;
  final int awardedGold;
  final bool wasCapped;
  const DailyCapResult({
    required this.awardedExp,
    required this.awardedGold,
    required this.wasCapped,
  });
}

class RewardCalculatorService {
  const RewardCalculatorService();

  RewardCalculationResult calculateAutoReward({
    required int difficulty,
    required int estimatedMinutes,
    required ActivityType activityType,
    int subTaskCount = 0,
  }) {
    if (difficulty < 1 || difficulty > 5) {
      throw ArgumentError.value(
        difficulty,
        'difficulty',
        'must be between 1 and 5',
      );
    }
    if (estimatedMinutes < 0) {
      throw ArgumentError.value(
        estimatedMinutes,
        'estimatedMinutes',
        'must not be negative',
      );
    }

    if (difficulty >= GamificationConfig.gatekeeperDifficultyThreshold &&
        estimatedMinutes < GamificationConfig.gatekeeperMinMinutes) {
      return RewardCalculationResult.blocked(
        'ความยากระดับนี้ต้องใช้เวลาอย่างน้อย '
        '${GamificationConfig.gatekeeperMinMinutes} นาที '
        '(ตั้งไว้ $estimatedMinutes นาที)',
      );
    }

    final diffMult = GamificationConfig.difficultyMultipliers[difficulty]!;
    final actMult = GamificationConfig.activityTypeMultipliers[activityType]!;

    final firstTier = min(estimatedMinutes, 30).toDouble();
    final secondTier = min(max(estimatedMinutes - 30, 0), 30).toDouble();
    final thirdTier = max(estimatedMinutes - 60, 0).toDouble();
    final effectiveMinutes = firstTier + (secondTier * 0.6) + (thirdTier * 0.3);
    final rewardedSubTasks = min(
      subTaskCount,
      GamificationConfig.maxRewardedSubTasks,
    );
    final rawExp =
      (effectiveMinutes * GamificationConfig.baseExpPerMinute * diffMult * actMult) +
      (rewardedSubTasks * GamificationConfig.expPerSubTask);
    final rawGold = rawExp * GamificationConfig.goldToExpRatio;

    final exp = max(GamificationConfig.minExpReward, rawExp.round());
    final gold = max(GamificationConfig.minGoldReward, rawGold.round());

    return RewardCalculationResult(
      isAllowed: true,
      expReward: exp,
      goldReward: gold,
    );
  }

  StreakAdjustedReward applyStreakMultiplier({
    required int baseExp,
    required int baseGold,
    required int streakCount,
  }) {
    final bonus = (streakCount * GamificationConfig.streakBonusPerDay).clamp(
      0.0,
      GamificationConfig.maxStreakBonus,
    );
    final multiplier = 1.0 + bonus;
    return StreakAdjustedReward(
      exp: (baseExp * multiplier).round(),
      gold: (baseGold * multiplier).round(),
      multiplierApplied: multiplier,
    );
  }

  /// โบนัส EXP จริงจากการเลือกสาย RPG Class แล้ว (+15% เท่ากันทุกสาย) —
  /// คูณต่อจาก streak multiplier ไปอีกชั้น ก่อนเข้า Daily Cap
  int applyClassBonus({required int exp, required bool hasRpgClass}) {
    if (!hasRpgClass) return exp;
    return (exp * (1 + GamificationConfig.rpgClassExpBonus)).round();
  }

  int applyConcurrentBonus({required int reward, required bool isConcurrent}) {
    if (!isConcurrent) return reward;
    return (reward * (1 + GamificationConfig.concurrentQuestBonus)).round();
  }

  DailyCapResult applyDailyCap({
    required int proposedExp,
    required int proposedGold,
    required int alreadyEarnedExpToday,
    required int alreadyEarnedGoldToday,
  }) {
    final remainingExp =
        (GamificationConfig.dailyExpCap - alreadyEarnedExpToday).clamp(
          0,
          GamificationConfig.dailyExpCap,
        );
    final remainingGold =
        (GamificationConfig.dailyGoldCap - alreadyEarnedGoldToday).clamp(
          0,
          GamificationConfig.dailyGoldCap,
        );
    final awardedExp = min(proposedExp, remainingExp);
    final awardedGold = min(proposedGold, remainingGold);
    return DailyCapResult(
      awardedExp: awardedExp,
      awardedGold: awardedGold,
      wasCapped: awardedExp < proposedExp || awardedGold < proposedGold,
    );
  }

  DailyCapResult resolveQuestCompletionReward({
    required int baseExp,
    required int baseGold,
    required int streakCount,
    required int alreadyEarnedExpToday,
    required int alreadyEarnedGoldToday,
    bool hasRpgClass = false,
    bool isConcurrent = false,
  }) {
    final streakAdj = applyStreakMultiplier(
      baseExp: baseExp,
      baseGold: baseGold,
      streakCount: streakCount,
    );
    final expWithClassBonus = applyClassBonus(
      exp: streakAdj.exp,
      hasRpgClass: hasRpgClass,
    );
    final expWithConcurrentBonus = applyConcurrentBonus(
      reward: expWithClassBonus,
      isConcurrent: isConcurrent,
    );
    final goldWithConcurrentBonus = applyConcurrentBonus(
      reward: streakAdj.gold,
      isConcurrent: isConcurrent,
    );
    return applyDailyCap(
      proposedExp: expWithConcurrentBonus,
      proposedGold: goldWithConcurrentBonus,
      alreadyEarnedExpToday: alreadyEarnedExpToday,
      alreadyEarnedGoldToday: alreadyEarnedGoldToday,
    );
  }
}
