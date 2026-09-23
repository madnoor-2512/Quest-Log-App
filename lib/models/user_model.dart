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
  });

  int get streakDays => streakCount;
  String? get lastLoginDate => lastActiveDate;

  /// สร้าง object ใหม่จาก object เดิม พร้อมค่าที่เปลี่ยนแปลง
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
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, level: $level, exp: $currentExp/$maxExp, gold: $gold, streak: $streakCount)';
}
