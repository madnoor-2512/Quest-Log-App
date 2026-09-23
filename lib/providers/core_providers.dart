import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../services/reward_calculator_service.dart';
import '../services/quest_conflict_service.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final rewardCalculatorProvider = Provider<RewardCalculatorService>((ref) {
  return const RewardCalculatorService();
});

final questConflictServiceProvider = Provider<QuestConflictService>((ref) {
  return const QuestConflictService();
});
