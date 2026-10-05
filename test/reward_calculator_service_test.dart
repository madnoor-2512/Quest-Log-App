import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/services/gamification_config.dart';
import 'package:quest_log/services/reward_calculator_service.dart';

void main() {
  group('RewardCalculatorService diamond drop schedule', () {
    test('mini bosses award a small diamond bonus in the planned range', () {
      final service = const RewardCalculatorService();
      final drop = service.calculateBossDiamondReward(isMiniBoss: true);

      expect(drop, inInclusiveRange(
        GamificationConfig.miniBossDiamondMin,
        GamificationConfig.miniBossDiamondMax,
      ));
    });

    test('final bosses award a larger diamond bonus in the planned range', () {
      final service = const RewardCalculatorService();
      final drop = service.calculateBossDiamondReward(isFinalBoss: true);

      expect(drop, inInclusiveRange(
        GamificationConfig.finalBossDiamondMin,
        GamificationConfig.finalBossDiamondMax,
      ));
    });
  });
}
