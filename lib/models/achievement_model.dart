/// เงื่อนไขการปลดล็อก Achievement — จำกัดเฉพาะสถิติที่มีอยู่แล้วจริงใน
/// แอป (streak count, จำนวนเควสที่ทำสำเร็จสะสม) ไม่สร้างสถิติใหม่ที่ไม่มี
/// อยู่จริง
enum AchievementConditionType { streakDays, questsCompleted }

/// นิยาม Achievement หนึ่งอัน — เป็น catalog คงที่เขียนไว้ในโค้ด (ไม่ใช่
/// ของที่ผู้ใช้สร้างเองแบบ rewards) เพราะเงื่อนไขปลดล็อกผูกกับ logic
/// ตายตัว จึงไม่มีประโยชน์ที่จะให้แก้ไขผ่าน DB
class AchievementDef {
  final String code; // unique key เก็บใน DB
  final String title;
  final String description;
  final String iconName;
  final AchievementConditionType conditionType;
  final int conditionValue;

  const AchievementDef({
    required this.code,
    required this.title,
    required this.description,
    required this.iconName,
    required this.conditionType,
    required this.conditionValue,
  });

  /// เช็คว่าเงื่อนไขนี้ผ่านหรือยัง จากสถิติปัจจุบัน
  bool isMetBy({required int streakDays, required int questsCompleted}) {
    switch (conditionType) {
      case AchievementConditionType.streakDays:
        return streakDays >= conditionValue;
      case AchievementConditionType.questsCompleted:
        return questsCompleted >= conditionValue;
    }
  }
}

/// Catalog ทั้งหมด — เรียงจากง่ายไปยาก
const List<AchievementDef> kAchievementCatalog = [
  AchievementDef(
    code: 'quests_10',
    title: 'นักผจญภัยมือใหม่',
    description: 'ทำเควสสำเร็จครบ 10 อัน',
    iconName: 'military_tech',
    conditionType: AchievementConditionType.questsCompleted,
    conditionValue: 10,
  ),
  AchievementDef(
    code: 'streak_7',
    title: 'นักสู้ 7 วัน',
    description: 'ทำเควสต่อเนื่องครบ 7 วันติดต่อกัน',
    iconName: 'local_fire_department',
    conditionType: AchievementConditionType.streakDays,
    conditionValue: 7,
  ),
  AchievementDef(
    code: 'quests_50',
    title: 'นักล่าเควสมืออาชีพ',
    description: 'ทำเควสสำเร็จครบ 50 อัน',
    iconName: 'workspace_premium',
    conditionType: AchievementConditionType.questsCompleted,
    conditionValue: 50,
  ),
  AchievementDef(
    code: 'streak_30',
    title: 'ตำนานความสม่ำเสมอ',
    description: 'ทำเควสต่อเนื่องครบ 30 วันติดต่อกัน',
    iconName: 'emoji_events',
    conditionType: AchievementConditionType.streakDays,
    conditionValue: 30,
  ),
  AchievementDef(
    code: 'quests_100',
    title: 'ตำนานนักผจญภัย',
    description: 'ทำเควสสำเร็จครบ 100 อัน',
    iconName: 'auto_awesome',
    conditionType: AchievementConditionType.questsCompleted,
    conditionValue: 100,
  ),
];

/// แถวใน DB ที่บันทึกว่าปลดล็อกอันไหนไปแล้วเมื่อไหร่
class UnlockedAchievementModel {
  final int? id;
  final String code;
  final String unlockedAt; // ISO8601

  const UnlockedAchievementModel({
    this.id,
    required this.code,
    required this.unlockedAt,
  });

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'code': code, 'unlocked_at': unlockedAt};
  }

  factory UnlockedAchievementModel.fromMap(Map<String, dynamic> map) {
    return UnlockedAchievementModel(
      id: map['id'] as int?,
      code: map['code'] as String,
      unlockedAt: map['unlocked_at'] as String,
    );
  }
}
