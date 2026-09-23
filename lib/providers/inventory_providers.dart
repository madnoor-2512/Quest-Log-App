import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reward_model.dart';
import '../services/gamification_config.dart';
import 'core_providers.dart';
import 'focus_providers.dart';
import 'user_provider.dart';

final inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, List<InventoryEntry>>(
      InventoryNotifier.new,
    );

class InventoryNotifier extends AsyncNotifier<List<InventoryEntry>> {
  @override
  Future<List<InventoryEntry>> build() async {
    final db = ref.read(databaseHelperProvider);
    return db.getInventory();
  }

  Future<void> _refresh() async {
    final db = ref.read(databaseHelperProvider);
    state = await AsyncValue.guard(() => db.getInventory());
  }

  /// สวม equipment ที่เลือก (unequip ตัวเก่าอัตโนมัติ) — เฉพาะไอเทม
  /// category equipment เท่านั้นที่เรียกอันนี้ได้ตาม UI
  Future<void> equip(InventoryEntry entry) async {
    if (entry.item.id == null) return;
    final db = ref.read(databaseHelperProvider);
    await db.equipInventoryItem(entry.item.id!);
    await _refresh();
  }

  /// ใช้ consumable 1 ชิ้น — ลด quantity แล้ว apply effect จริงตาม
  /// effectType ของ reward ที่ผูกอยู่ คืนค่าข้อความสรุปผลให้ UI โชว์
  /// SnackBar (หรือ throw ถ้าใช้ไม่ได้ เช่น extendFocusMinutes ตอนไม่มี
  /// session active)
  Future<String> use(InventoryEntry entry) async {
    if (entry.item.id == null) {
      throw StateError('ไอเทมนี้ไม่มี id ใช้ไม่ได้');
    }

    // เช็คก่อนว่าใช้ได้จริงไหม สำหรับ effect ที่มีเงื่อนไข — เช็คก่อนหัก
    // ของออกจากคลัง กันกรณีเสียของไปฟรีๆ ตอนใช้ไม่ได้
    if (entry.reward.effectType == ItemEffectType.extendFocusMinutes) {
      final hasActiveSession =
          ref.read(activeFocusSessionProvider).valueOrNull != null;
      if (!hasActiveSession) {
        throw StateError(
          'ต้องมีเซสชันโฟกัสที่กำลังทำงานอยู่ก่อนถึงจะใช้ไอเทมนี้ได้',
        );
      }
    }

    final db = ref.read(databaseHelperProvider);
    final usedReward = await db.useInventoryItem(entry.item.id!);
    if (usedReward == null) {
      throw StateError('ไม่พบไอเทมนี้ในคลังแล้ว');
    }

    final message = await _applyEffect(usedReward);
    await _refresh();
    return message;
  }

  Future<String> _applyEffect(RewardModel reward) async {
    final value = reward.effectValue ?? 0;
    switch (reward.effectType) {
      case ItemEffectType.instantExp:
        await ref
            .read(userProvider.notifier)
            .addExpAndGold(exp: value.round(), gold: 0);
        return 'ได้รับ +${value.round()} EXP ทันที!';
      case ItemEffectType.instantGold:
        await ref
            .read(userProvider.notifier)
            .addExpAndGold(exp: 0, gold: value.round());
        return 'ได้รับ +${value.round()} Gold ทันที!';
      case ItemEffectType.extendFocusMinutes:
        final ok = await ref
            .read(activeFocusSessionProvider.notifier)
            .extendActiveSession(value.round());
        return ok
            ? 'ต่อเวลาโฟกัสเพิ่ม +${value.round()} นาที!'
            : 'ใช้ไอเทมไม่สำเร็จ ไม่มีเซสชันโฟกัสที่กำลังทำงานอยู่';
      case ItemEffectType.focusTimeBonusPercent:
        // ไอเทมประเภทนี้ปกติเป็น equipment (สวมใส่แบบ passive) ไม่ได้ใช้
        // ผ่านปุ่ม "ใช้" แบบ consumable แต่กันไว้เผื่อมีคนตั้ง reward ผิด
        // หมวดหมู่
        return 'ไอเทมนี้เป็นของสวมใส่ ให้กดปุ่ม "สวมใส่" แทนการใช้';
      case ItemEffectType.none:
        return 'ใช้ไอเทมเรียบร้อย';
    }
  }

  /// ขยายช่องคลัง — หัก Gold ผ่าน userProvider ก่อน แล้วค่อยขยายจริงใน DB
  /// ถ้า Gold ไม่พอ return false โดยไม่แตะ capacity เลย
  Future<bool> expandCapacity() async {
    final user = ref.read(userProvider).valueOrNull;
    if (user?.id == null) return false;

    final spent = await ref
        .read(userProvider.notifier)
        .spendGold(GamificationConfig.inventoryExpandCost);
    if (!spent) return false;

    final db = ref.read(databaseHelperProvider);
    await db.expandInventoryCapacity(
      user!.id!,
      GamificationConfig.inventoryExpandAmount,
    );
    await ref.read(userProvider.notifier).refresh();
    await _refresh();
    return true;
  }
}

/// จำนวนช่องคลังที่ใช้ไปแล้ว (นับเป็นจำนวนไอเทมต่างชนิดกัน ไม่ใช่ quantity
/// รวม — ของซ้ำ stack กันเป็นช่องเดียว)
final inventoryUsedSlotsProvider = Provider<int>((ref) {
  return ref.watch(inventoryProvider).valueOrNull?.length ?? 0;
});
