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
  final int streakCount;
  final String? lastActiveDate; // ISO8601 string, e.g. 2026-09-17
  final int avatarIndex; // index เข้า heroAvatarIcons ใน theme/app_avatars.dart
  final int inventoryCapacity; // จำนวนช่องคลังไอเทมสูงสุด ขยายได้ด้วย Gold
  final String? username; // @handle แสดงในโปรไฟล์ ไม่ผูกกับ auth ใดๆ
  final String? motto; // คติประจำใจ / bio สั้นๆ
  final RpgClassPath? rpgClass; // null = ยังไม่ได้เลือกสาย

  const UserModel({
    this.id,
    required this.name,
    this.level = 1,
    this.currentExp = 0,
    this.maxExp = 100,
    this.gold = 0,
    this.streakCount = 0,
    this.lastActiveDate,
    this.avatarIndex = 0,
    this.inventoryCapacity = 20,
    this.username,
    this.motto,
    this.rpgClass,
  });

  int get streakDays => streakCount;
  String? get lastLoginDate => lastActiveDate;

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
    int? streakCount,
    String? lastActiveDate,
    int? avatarIndex,
    int? inventoryCapacity,
    String? username,
    String? motto,
    RpgClassPath? rpgClass,
    bool clearRpgClass = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      maxExp: maxExp ?? this.maxExp,
      gold: gold ?? this.gold,
      streakCount: streakCount ?? this.streakCount,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      inventoryCapacity: inventoryCapacity ?? this.inventoryCapacity,
      username: username ?? this.username,
      motto: motto ?? this.motto,
      rpgClass: clearRpgClass ? null : (rpgClass ?? this.rpgClass),
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
      'streak_count': streakCount,
      'last_active_date': lastActiveDate,
      'avatar_index': avatarIndex,
      'inventory_capacity': inventoryCapacity,
      'username': username,
      'motto': motto,
      'rpg_class': rpgClass?.dbValue,
    };
  }

  /// สร้าง object จาก Map ที่อ่านมาจาก SQLite
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      level: map['level'] as int? ?? 1,
      currentExp: map['current_exp'] as int? ?? 0,
      maxExp: map['max_exp'] as int? ?? 100,
      gold: map['gold'] as int? ?? 0,
      streakCount: map['streak_count'] as int? ?? 0,
      lastActiveDate: map['last_active_date'] as String?,
      avatarIndex: map['avatar_index'] as int? ?? 0,
      inventoryCapacity: map['inventory_capacity'] as int? ?? 20,
      username: map['username'] as String?,
      motto: map['motto'] as String?,
      rpgClass: RpgClassPathX.fromDb(map['rpg_class'] as String?),
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, level: $level, exp: $currentExp/$maxExp, gold: $gold, streak: $streakCount)';
}
