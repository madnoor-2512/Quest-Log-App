import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reward_model.dart';
import 'core_providers.dart';
import 'inventory_providers.dart';
import 'user_provider.dart';

final rewardsListProvider =
    AsyncNotifierProvider<RewardsListNotifier, List<RewardModel>>(
      RewardsListNotifier.new,
    );

class RewardsListNotifier extends AsyncNotifier<List<RewardModel>> {
  @override
  Future<List<RewardModel>> build() async {
    final db = ref.read(databaseHelperProvider);
    return db.getAllRewards();
  }

  Future<void> addReward(RewardModel reward) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertReward(reward);
    state = await AsyncValue.guard(() => db.getAllRewards());
  }

  Future<void> updateReward(RewardModel reward) async {
    final db = ref.read(databaseHelperProvider);
    await db.updateReward(reward);
    state = await AsyncValue.guard(() => db.getAllRewards());
  }

  Future<void> deleteReward(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteReward(id);
    state = await AsyncValue.guard(() => db.getAllRewards());
  }

  /// แลกของรางวัล — คืน RedeemOutcome แทน bool เพราะเหตุผลที่แลกไม่ผ่าน
  /// มีได้ 2 แบบตอนนี้ (Gold ไม่พอ / คลังเต็ม) ที่ UI ควรโชว์ข้อความต่างกัน
  Future<RedeemOutcome> redeem(int rewardId) async {
    final user = ref.read(userProvider).valueOrNull;
    if (user?.id == null) return RedeemOutcome.notEnoughGold;

    final db = ref.read(databaseHelperProvider);
    final outcome = await db.redeemReward(
      userId: user!.id!,
      rewardId: rewardId,
    );

    if (outcome == RedeemOutcome.success) {
      await ref.read(userProvider.notifier).refresh();
      ref.invalidate(inventoryProvider);
    }
    return outcome;
  }
}
