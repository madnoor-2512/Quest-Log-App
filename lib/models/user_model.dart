/// สายพลังตัวละคร (RPG Class) — เลือกได้ทีเดียว ให้โบนัส EXP จริงๆ
/// +15% ทุกเควสที่ทำสำเร็จ (ไม่ว่าจะเลือกสายไหนก็ได้โบนัสเท่ากัน เป็น
/// "รางวัลจากการเลือกสาย" ไม่ใช่ค่าที่ต่างกันต่อสาย — ดู
/// GamificationConfig.rpgClassExpBonus)
enum RpgClassPath { strength, intelligence, dexterity }

extension RpgClassPathX on RpgClassPath {
  String? get dbValue {
    switch (this) {
      case RpgClassPath.strength:
        return 'STR';
      case RpgClassPath.intelligence:
        return 'INT';
      case RpgClassPath.dexterity:
        return 'DEX';
    }
  }

  String get shortLabel {
    switch (this) {
      case RpgClassPath.strength:
        return 'สาย STR';
      case RpgClassPath.intelligence:
        return 'สาย INT';
      case RpgClassPath.dexterity:
        return 'สาย DEX';
    }
  }

  String get statLabel {
    switch (this) {
      case RpgClassPath.strength:
        return 'พลังกาย';
      case RpgClassPath.intelligence:
        return 'ปัญญา';
      case RpgClassPath.dexterity:
        return 'ความคล่องแคล่ว';
    }
  }

  /// ใช้ต่อกับ "Lv.X " เป็นชื่อคลาสเต็ม เช่น "Lv.1 Sage of Mindfulness"
  String get classTitle {
    switch (this) {
      case RpgClassPath.strength:
        return 'Warrior of Discipline';
      case RpgClassPath.intelligence:
        return 'Sage of Mindfulness';
      case RpgClassPath.dexterity:
        return 'Trickster of Agility';
    }
  }

  static RpgClassPath? fromDb(String? value) {
    switch (value) {
      case 'STR':
        return RpgClassPath.strength;
      case 'INT':
        return RpgClassPath.intelligence;
      case 'DEX':
        return RpgClassPath.dexterity;
      default:
        return null;
    }
  }
}

/// User model
/// เก็บสถานะตัวละคร (Character Stats) ของผู้เล่น
class UserModel {
  final int? id;
  final String name;
  final int level;
  final int currentExp;
  final int maxExp;
  final int gold;
  final int gems; // 💎 Hard currency
  final int currentHp; // ❤️ พลังชีวิตปัจจุบัน
  final int maxHp; // ❤️ พลังชีวิตสูงสุด
  final int streakCount;
  final String? lastActiveDate; // ISO8601 string, e.g. 2026-09-17
  final int avatarIndex; // index เข้า heroAvatarIcons ใน theme/app_avatars.dart
  final int inventoryCapacity; // จำนวนช่องคลังไอเทมสูงสุด ขยายได้ด้วย Gold
  final String? username; // @handle แสดงในโปรไฟล์ ไม่ผูกกับ auth ใดๆ
  final String? motto; // คติประจำใจ / bio สั้นๆ
  final RpgClassPath? rpgClass; // null = ยังไม่ได้เลือกสาย
  final bool isStreakFrozen;
  final int missedDaysCount;
  final bool hasStreakDebuff;
  final int streakBeforeReset;
  final String? streakFrozenUntil;
  final bool meltExpBonusPending;
  final String? streakResetAt;

  const UserModel({
    this.id,
    required this.name,
    this.level = 1,
    this.currentExp = 0,
    this.maxExp = 100,
    this.gold = 0,
    this.gems = 10,
    this.currentHp = 100,
    this.maxHp = 100,
    this.streakCount = 0,
    this.lastActiveDate,
    this.avatarIndex = 0,
    this.inventoryCapacity = 20,
    this.username,
    this.motto,
    this.rpgClass,
    this.isStreakFrozen = false,
    this.missedDaysCount = 0,
    this.hasStreakDebuff = false,
    this.streakBeforeReset = 0,
    this.streakFrozenUntil,
    this.meltExpBonusPending = false,
    this.streakResetAt,
  });

  int get streakDays => streakCount;
  String? get lastLoginDate => lastActiveDate;

  UserModel withRewards({
    required int exp,
    required int gold,
    int hpGain = 0,
    int bonusGems = 0,
  }) {
    final adjustedExp = meltExpBonusPending
        ? (exp * 1.25).round()
        : exp;
    var nextExp = currentExp + adjustedExp;
    var nextLevel = level;
    var nextMaxExp = maxExp;
    var nextMaxHp = maxHp;
    var nextGems = gems + bonusGems;
    var levelsGained = 0;

    while (nextExp >= nextMaxExp) {
      nextExp -= nextMaxExp;
      nextLevel += 1;
      levelsGained += 1;
      nextMaxExp = (nextMaxExp * 1.2).round();
      nextMaxHp = 100 + (nextLevel - 1) * 10;
      nextGems += 5; // เลเวลอัป มอบรางวัลโบนัสเพชร +5
    }

    // HP heal & overflow logic
    var newHp = currentHp + hpGain;
    var overflowGold = 0;
    if (levelsGained > 0) {
      // เลเวลอัป ขยายหลอด Max HP และฟื้นฟูเต็มหลอด
      newHp = nextMaxHp;
    } else {
      if (newHp > nextMaxHp) {
        overflowGold = newHp - nextMaxHp; // หาก HP เต็ม 100% ส่วนที่ล้นจะถูกแปลงเป็นโบนัสเหรียญทอง
        newHp = nextMaxHp;
      }
    }

    return copyWith(
      level: nextLevel,
      currentExp: nextExp,
      maxExp: nextMaxExp,
      maxHp: nextMaxHp,
      currentHp: newHp,
      gold: this.gold + gold + overflowGold,
      gems: nextGems,
      meltExpBonusPending: false,
    );
  }

  /// ลด HP เมื่อทำเควสต์ล้มเหลว หรือไฟดับ
  /// หาก HP เหลือ 0: โดนลงโทษ "ลดเลเวล 1 ขั้น" และ item debuff
  UserModel applyHpDamage(int damage) {
    var newHp = currentHp - damage;
    if (newHp <= 0) {
      final newLevel = (level > 1) ? level - 1 : 1;
      final newMaxHp = 100 + (newLevel - 1) * 10;
      return copyWith(
        level: newLevel,
        currentHp: (newMaxHp * 0.5).round(),
        maxHp: newMaxHp,
        hasStreakDebuff: true, // ไอเทมสวมใส่โดนลดประสิทธิภาพชั่วคราว
      );
    }
    return copyWith(currentHp: newHp);
  }

  /// สร้าง object ใหม่จาก object เดิม พร้อมค่าที่เปลี่ยนแปลง
  ///
  /// หมายเหตุ [clearRpgClass]: เพราะ [rpgClass] เป็น nullable และ
  /// copyWith ปกติจะ "ค่า null = ไม่เปลี่ยน" ทำให้ set กลับเป็น null
  /// ตรงๆ ผ่าน [rpgClass] ไม่ได้ ต้องส่ง [clearRpgClass] = true แทน
  UserModel copyWith({
    int? id,
    String? name,
    int? level,
    int? currentExp,
    int? maxExp,
    int? gold,
    int? gems,
    int? currentHp,
    int? maxHp,
    int? streakCount,
    String? lastActiveDate,
    int? avatarIndex,
    int? inventoryCapacity,
    String? username,
    String? motto,
    RpgClassPath? rpgClass,
    bool clearUsername = false,
    bool clearMotto = false,
    bool clearRpgClass = false,
    bool? isStreakFrozen,
    int? missedDaysCount,
    bool? hasStreakDebuff,
    int? streakBeforeReset,
    String? streakFrozenUntil,
    bool? meltExpBonusPending,
    String? streakResetAt,
    bool clearStreakFrozenUntil = false,
    bool clearStreakResetAt = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      maxExp: maxExp ?? this.maxExp,
      gold: gold ?? this.gold,
      gems: gems ?? this.gems,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      streakCount: streakCount ?? this.streakCount,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      inventoryCapacity: inventoryCapacity ?? this.inventoryCapacity,
      username: clearUsername ? null : (username ?? this.username),
      motto: clearMotto ? null : (motto ?? this.motto),
      rpgClass: clearRpgClass ? null : (rpgClass ?? this.rpgClass),
      isStreakFrozen: isStreakFrozen ?? this.isStreakFrozen,
      missedDaysCount: missedDaysCount ?? this.missedDaysCount,
      hasStreakDebuff: hasStreakDebuff ?? this.hasStreakDebuff,
      streakBeforeReset: streakBeforeReset ?? this.streakBeforeReset,
      streakFrozenUntil: clearStreakFrozenUntil
          ? null
          : (streakFrozenUntil ?? this.streakFrozenUntil),
      meltExpBonusPending: meltExpBonusPending ?? this.meltExpBonusPending,
      streakResetAt: clearStreakResetAt
          ? null
          : (streakResetAt ?? this.streakResetAt),
    );
  }

  /// แปลงเป็น Map สำหรับบันทึกลง SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'level': level,
      'current_exp': currentExp,
      'max_exp': maxExp,
      'gold': gold,
      'gems': gems,
      'current_hp': currentHp,
      'max_hp': maxHp,
      'streak_count': streakCount,
      'last_active_date': lastActiveDate,
      'avatar_index': avatarIndex,
      'inventory_capacity': inventoryCapacity,
      'username': username,
      'motto': motto,
      'rpg_class': rpgClass?.dbValue,
      'is_streak_frozen': isStreakFrozen ? 1 : 0,
      'missed_days_count': missedDaysCount,
      'has_streak_debuff': hasStreakDebuff ? 1 : 0,
      'streak_before_reset': streakBeforeReset,
      'streak_frozen_until': streakFrozenUntil,
      'melt_exp_bonus_pending': meltExpBonusPending ? 1 : 0,
      'streak_reset_at': streakResetAt,
    };
  }

  /// สร้าง object จาก Map ที่อ่านมาจาก SQLite
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final lvl = map['level'] as int? ?? 1;
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      level: lvl,
      currentExp: map['current_exp'] as int? ?? 0,
      maxExp: map['max_exp'] as int? ?? 100,
      gold: map['gold'] as int? ?? 0,
      gems: map['gems'] as int? ?? 10,
      currentHp: map['current_hp'] as int? ?? (100 + (lvl - 1) * 10),
      maxHp: map['max_hp'] as int? ?? (100 + (lvl - 1) * 10),
      streakCount: map['streak_count'] as int? ?? 0,
      lastActiveDate: map['last_active_date'] as String?,
      avatarIndex: map['avatar_index'] as int? ?? 0,
      inventoryCapacity: map['inventory_capacity'] as int? ?? 20,
      username: map['username'] as String?,
      motto: map['motto'] as String?,
      rpgClass: RpgClassPathX.fromDb(map['rpg_class'] as String?),
      isStreakFrozen: (map['is_streak_frozen'] as int? ?? 0) == 1,
      missedDaysCount: map['missed_days_count'] as int? ?? 0,
      hasStreakDebuff: (map['has_streak_debuff'] as int? ?? 0) == 1,
      streakBeforeReset: map['streak_before_reset'] as int? ?? 0,
      streakFrozenUntil: map['streak_frozen_until'] as String?,
      meltExpBonusPending: (map['melt_exp_bonus_pending'] as int? ?? 0) == 1,
      streakResetAt: map['streak_reset_at'] as String?,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, level: $level, exp: $currentExp/$maxExp, gold: $gold, streak: $streakCount)';
}
