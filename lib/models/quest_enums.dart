/// หมวดหมู่ของเควส
enum QuestCategory { main, side, daily }

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

/// ประเภทของกิจกรรม ใช้สำหรับตรวจสอบ Conflict ตอนทำ Multi-Quest Focus
enum ActivityType { physicalHeavy, stillness, audioOnly, mental }

extension ActivityTypeX on ActivityType {
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
      default:
        throw ArgumentError('Unknown ActivityType: $value');
    }
  }
}
