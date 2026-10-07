/// หมวดหมู่ของเควส
enum QuestCategory { main, side, daily }

enum QuestGoalType { focus, dailyHabit }

extension QuestGoalTypeX on QuestGoalType {
  String get dbValue => this == QuestGoalType.focus ? 'FOCUS' : 'DAILY_HABIT';

  String get displayName =>
      this == QuestGoalType.focus ? 'Focus Quest' : 'Daily Habit / Check-in';

  static QuestGoalType fromDb(String? value) =>
      value == 'DAILY_HABIT' ? QuestGoalType.dailyHabit : QuestGoalType.focus;
}

extension QuestCategoryX on QuestCategory {
  String get dbValue {
    switch (this) {
      case QuestCategory.main:
        return 'MAIN';
      case QuestCategory.side:
        return 'SIDE';
      case QuestCategory.daily:
        return 'DAILY';
    }
  }

  String get displayName {
    switch (this) {
      case QuestCategory.main:
        return 'Main';
      case QuestCategory.side:
        return 'Side';
      case QuestCategory.daily:
        return 'Daily';
    }
  }

  static QuestCategory fromDb(String value) {
    switch (value.toUpperCase()) {
      case 'MAIN':
        return QuestCategory.main;
      case 'SIDE':
        return QuestCategory.side;
      case 'DAILY':
        return QuestCategory.daily;
      default:
        throw ArgumentError('Unknown QuestCategory: $value');
    }
  }
}

/// ความถี่ในการทำ "เควสต์ทันใจ" (Daily Habit) — กำหนดว่าวันไหนบ้างใน
/// สัปดาห์ที่เควสต์นี้ควรถูกเช็กอิน เลือกได้จากหน้าสร้างเควสต์ทันใจ
enum HabitFrequency { daily, weekdays, custom }

extension HabitFrequencyX on HabitFrequency {
  String get dbValue {
    switch (this) {
      case HabitFrequency.daily:
        return 'DAILY';
      case HabitFrequency.weekdays:
        return 'WEEKDAYS';
      case HabitFrequency.custom:
        return 'CUSTOM';
    }
  }

  String get displayName {
    switch (this) {
      case HabitFrequency.daily:
        return 'ทุกวัน';
      case HabitFrequency.weekdays:
        return 'จันทร์-ศุกร์';
      case HabitFrequency.custom:
        return 'กำหนดเอง';
    }
  }

  /// วันในสัปดาห์ (ISO weekday: 1=จันทร์ ... 7=อาทิตย์) ที่ควรทำเควสต์
  /// ตามความถี่ที่เลือกไว้ — ใช้ได้เฉพาะ daily/weekdays ที่เป็นชุดวันตายตัว
  /// ส่วน custom ผู้ใช้เลือกเองผ่าน QuestModel.habitCustomWeekdays
  List<int> get fixedWeekdays {
    switch (this) {
      case HabitFrequency.daily:
        return const [1, 2, 3, 4, 5, 6, 7];
      case HabitFrequency.weekdays:
        return const [1, 2, 3, 4, 5];
      case HabitFrequency.custom:
        return const [];
    }
  }

  static HabitFrequency fromDb(String? value) {
    switch (value) {
      case 'WEEKDAYS':
        return HabitFrequency.weekdays;
      case 'CUSTOM':
        return HabitFrequency.custom;
      default:
        return HabitFrequency.daily;
    }
  }
}

/// ประเภทของกิจกรรม ใช้สำหรับตรวจสอบ Conflict ตอนทำ Multi-Quest Focus
enum ActivityType { physicalHeavy, stillness, audioOnly, mental, visual }

enum ResourcePool { physical, cognitive, auditory, visual }

extension ResourcePoolX on ResourcePool {
  String get displayName => switch (this) {
    ResourcePool.physical => 'ร่างกาย',
    ResourcePool.cognitive => 'สมอง',
    ResourcePool.auditory => 'หู',
    ResourcePool.visual => 'สายตา',
  };
}

extension ActivityTypeX on ActivityType {
  ResourcePool get resourcePool {
    switch (this) {
      case ActivityType.physicalHeavy:
      case ActivityType.stillness:
        return ResourcePool.physical;
      case ActivityType.mental:
        return ResourcePool.cognitive;
      case ActivityType.audioOnly:
        return ResourcePool.auditory;
      case ActivityType.visual:
        return ResourcePool.visual;
    }
  }

  bool get isBackgroundAllowed => this == ActivityType.audioOnly;

  String get dbValue {
    switch (this) {
      case ActivityType.physicalHeavy:
        return 'PHYSICAL_HEAVY';
      case ActivityType.stillness:
        return 'STILLNESS';
      case ActivityType.audioOnly:
        return 'AUDIO_ONLY';
      case ActivityType.mental:
        return 'MENTAL';
      case ActivityType.visual:
        return 'VISUAL';
    }
  }

  String get displayName {
    switch (this) {
      case ActivityType.physicalHeavy:
        return 'Physical';
      case ActivityType.stillness:
        return 'Stillness';
      case ActivityType.audioOnly:
        return 'Audio Only';
      case ActivityType.mental:
        return 'Mental';
      case ActivityType.visual:
        return 'Visual';
    }
  }

  static ActivityType fromDb(String value) {
    switch (value.toUpperCase()) {
      case 'PHYSICAL_HEAVY':
        return ActivityType.physicalHeavy;
      case 'STILLNESS':
        return ActivityType.stillness;
      case 'AUDIO_ONLY':
        return ActivityType.audioOnly;
      case 'MENTAL':
        return ActivityType.mental;
      case 'VISUAL':
        return ActivityType.visual;
      default:
        throw ArgumentError('Unknown ActivityType: $value');
    }
  }
}
