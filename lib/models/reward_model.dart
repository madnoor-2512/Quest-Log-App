/// หมวดหมู่ของรางวัล — ตรงกับ filter chip ในหน้าคลังไอเทม
enum RewardCategory { equipment, consumable, collectible }

extension RewardCategoryX on RewardCategory {
  String get dbValue {
    switch (this) {
      case RewardCategory.equipment:
        return 'EQUIPMENT';
      case RewardCategory.consumable:
        return 'CONSUMABLE';
      case RewardCategory.collectible:
        return 'COLLECTIBLE';
    }
  }

  String get displayName {
    switch (this) {
      case RewardCategory.equipment:
        return 'อุปกรณ์';
      case RewardCategory.consumable:
        return 'น้ำยา/เวป';
      case RewardCategory.collectible:
        return 'ของสะสม';
    }
  }

  static RewardCategory fromDb(String value) {
    switch (value.toUpperCase()) {
      case 'EQUIPMENT':
        return RewardCategory.equipment;
      case 'CONSUMABLE':
        return RewardCategory.consumable;
      case 'COLLECTIBLE':
        return RewardCategory.collectible;
      default:
        return RewardCategory.consumable;
    }
  }
}

/// ระดับความหายาก — แค่ใช้แสดงผล (badge สี) ไม่มีผลต่อกลไกเกม
enum ItemRarity { common, rare, epic }

extension ItemRarityX on ItemRarity {
  String get dbValue {
    switch (this) {
      case ItemRarity.common:
        return 'COMMON';
      case ItemRarity.rare:
        return 'RARE';
      case ItemRarity.epic:
        return 'EPIC';
    }
  }

  String get displayName {
    switch (this) {
      case ItemRarity.common:
        return 'Common';
      case ItemRarity.rare:
        return 'Rare';
      case ItemRarity.epic:
        return 'Epic';
    }
  }

  static ItemRarity fromDb(String value) {
    switch (value.toUpperCase()) {
      case 'RARE':
        return ItemRarity.rare;
      case 'EPIC':
        return ItemRarity.epic;
      default:
        return ItemRarity.common;
    }
  }
}

/// ผลจริงที่ไอเทมมีต่อเกม — จำกัดเฉพาะกลไกที่มีอยู่แล้วในแอป (ไม่มีระบบ
/// HP/พลังงานสมมติขึ้นมาใหม่):
/// - focusTimeBonusPercent: ของ "อุปกรณ์" (equipment) ที่สวมใส่อยู่ —
///   ตอนเริ่ม Focus session ใหม่ target_duration จะถูกคูณเพิ่มอัตโนมัติ
/// - extendFocusMinutes: ของ "น้ำยา/เวป" (consumable) ใช้ครั้งเดียว —
///   บวกเวลาเพิ่มให้ session โฟกัสที่กำลัง active อยู่ตอนนั้นทันที
/// - instantExp / instantGold: ของ consumable ใช้ครั้งเดียว — บวก EXP/Gold
///   ให้ user ทันทีตอนกดใช้
enum ItemEffectType {
  none,
  focusTimeBonusPercent,
  extendFocusMinutes,
  instantExp,
  instantGold,
}

extension ItemEffectTypeX on ItemEffectType {
  String? get dbValue {
    switch (this) {
      case ItemEffectType.none:
        return null;
      case ItemEffectType.focusTimeBonusPercent:
        return 'FOCUS_TIME_BONUS_PERCENT';
      case ItemEffectType.extendFocusMinutes:
        return 'EXTEND_FOCUS_MINUTES';
      case ItemEffectType.instantExp:
        return 'INSTANT_EXP';
      case ItemEffectType.instantGold:
        return 'INSTANT_GOLD';
    }
  }

  /// ชื่อแสดงผล + หน่วยของ effectValue สำหรับ hint ในฟอร์มเพิ่มของรางวัล
  String get displayName {
    switch (this) {
      case ItemEffectType.none:
        return 'ไม่มีผล (แค่เก็บสะสม/ใช้ทั่วไป)';
      case ItemEffectType.focusTimeBonusPercent:
        return 'เพิ่ม Focus Time (%)';
      case ItemEffectType.extendFocusMinutes:
        return 'ต่อเวลาโฟกัส (นาที)';
      case ItemEffectType.instantExp:
        return 'ได้ EXP ทันที';
      case ItemEffectType.instantGold:
        return 'ได้ Gold ทันที';
    }
  }

  static ItemEffectType fromDb(String? value) {
    switch (value?.toUpperCase()) {
      case 'FOCUS_TIME_BONUS_PERCENT':
        return ItemEffectType.focusTimeBonusPercent;
      case 'EXTEND_FOCUS_MINUTES':
        return ItemEffectType.extendFocusMinutes;
      case 'INSTANT_EXP':
        return ItemEffectType.instantExp;
      case 'INSTANT_GOLD':
        return ItemEffectType.instantGold;
      default:
        return ItemEffectType.none;
    }
  }
}

/// rewards — ของรางวัล/ไอเทมในร้านค้าที่ผู้ใช้ตั้งค่าเอง
class RewardModel {
  final int? id;
  final String title;
  final String? description;
  final int goldCost;
  final String? iconName;
  final RewardCategory itemCategory;
  final ItemRarity rarity;
  final ItemEffectType effectType;
  final double? effectValue; // ความหมายขึ้นกับ effectType (% หรือ จำนวน)

  const RewardModel({
    this.id,
    required this.title,
    this.description,
    required this.goldCost,
    this.iconName,
    this.itemCategory = RewardCategory.consumable,
    this.rarity = ItemRarity.common,
    this.effectType = ItemEffectType.none,
    this.effectValue,
  });

  RewardModel copyWith({
    int? id,
    String? title,
    String? description,
    int? goldCost,
    String? iconName,
    RewardCategory? itemCategory,
    ItemRarity? rarity,
    ItemEffectType? effectType,
    double? effectValue,
  }) {
    return RewardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      goldCost: goldCost ?? this.goldCost,
      iconName: iconName ?? this.iconName,
      itemCategory: itemCategory ?? this.itemCategory,
      rarity: rarity ?? this.rarity,
      effectType: effectType ?? this.effectType,
      effectValue: effectValue ?? this.effectValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'gold_cost': goldCost,
      'icon_name': iconName,
      'item_category': itemCategory.dbValue,
      'rarity': rarity.dbValue,
      'effect_type': effectType.dbValue,
      'effect_value': effectValue,
    };
  }

  factory RewardModel.fromMap(Map<String, dynamic> map) {
    return RewardModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      goldCost: map['gold_cost'] as int,
      iconName: map['icon_name'] as String?,
      itemCategory: RewardCategoryX.fromDb(
        map['item_category'] as String? ?? 'CONSUMABLE',
      ),
      rarity: ItemRarityX.fromDb(map['rarity'] as String? ?? 'COMMON'),
      effectType: ItemEffectTypeX.fromDb(map['effect_type'] as String?),
      effectValue: (map['effect_value'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'RewardModel(id: $id, title: $title, goldCost: $goldCost, category: ${itemCategory.dbValue})';
}

/// redemptions — ประวัติการแลกของรางวัล (เก็บไว้เป็น audit log เบื้องหลัง
/// ไม่มีแท็บแยกแสดงแล้ว เพราะข้อมูล "เป็นเจ้าของอะไรบ้าง" ย้ายไปโชว์ผ่าน
/// คลังไอเทม (inventory_items) แทน)
class RedemptionModel {
  final int? id;
  final int rewardId;
  final String redeemedAt; // ISO8601

  const RedemptionModel({
    this.id,
    required this.rewardId,
    required this.redeemedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'reward_id': rewardId,
      'redeemed_at': redeemedAt,
    };
  }

  factory RedemptionModel.fromMap(Map<String, dynamic> map) {
    return RedemptionModel(
      id: map['id'] as int?,
      rewardId: map['reward_id'] as int,
      redeemedAt: map['redeemed_at'] as String,
    );
  }

  @override
  String toString() =>
      'RedemptionModel(id: $id, rewardId: $rewardId, redeemedAt: $redeemedAt)';
}

/// ผลลัพธ์ของการแลกของรางวัล — แยกเหตุผลที่แลกไม่สำเร็จให้ชัดเจน แทนที่
/// จะคืนแค่ bool เหมือนเดิม เพราะตอนนี้มีเหตุผลได้ 2 แบบ (Gold ไม่พอ /
/// คลังเต็ม) ที่ผู้ใช้ควรเห็นข้อความต่างกัน
enum RedeemOutcome { success, notEnoughGold, inventoryFull }

/// inventory_items — ไอเทมที่ผู้ใช้ "เป็นเจ้าของ" อยู่ตอนนี้ (1 แถวต่อ
/// reward 1 ชนิดที่ถือครองอยู่ — ของซ้ำสะสมที่ quantity ไม่ใช่แยกแถว)
class InventoryItemModel {
  final int? id;
  final int rewardId;
  final int quantity;
  final bool isEquipped;
  final String acquiredAt; // ISO8601 — ครั้งแรกที่ได้มา

  const InventoryItemModel({
    this.id,
    required this.rewardId,
    this.quantity = 1,
    this.isEquipped = false,
    required this.acquiredAt,
  });

  InventoryItemModel copyWith({
    int? id,
    int? rewardId,
    int? quantity,
    bool? isEquipped,
    String? acquiredAt,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      rewardId: rewardId ?? this.rewardId,
      quantity: quantity ?? this.quantity,
      isEquipped: isEquipped ?? this.isEquipped,
      acquiredAt: acquiredAt ?? this.acquiredAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'reward_id': rewardId,
      'quantity': quantity,
      'is_equipped': isEquipped ? 1 : 0,
      'acquired_at': acquiredAt,
    };
  }

  factory InventoryItemModel.fromMap(Map<String, dynamic> map) {
    return InventoryItemModel(
      id: map['id'] as int?,
      rewardId: map['reward_id'] as int,
      quantity: map['quantity'] as int? ?? 1,
      isEquipped: (map['is_equipped'] as int? ?? 0) == 1,
      acquiredAt: map['acquired_at'] as String,
    );
  }

  @override
  String toString() =>
      'InventoryItemModel(id: $id, rewardId: $rewardId, quantity: $quantity, equipped: $isEquipped)';
}

/// ไอเทมในคลัง + รายละเอียดของรางวัลที่ผูกอยู่ รวมมาด้วยกันเพื่อให้ UI
/// ไม่ต้อง join เอง — DatabaseHelper.getInventory() คืนค่าเป็น list ของ
/// ตัวนี้โดยตรง
class InventoryEntry {
  final InventoryItemModel item;
  final RewardModel reward;

  const InventoryEntry({required this.item, required this.reward});
}
