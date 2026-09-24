import 'quest_enums.dart';

class QuestModel {
  final int? id;
  final String title;
  final String? description;
  final QuestCategory category;
  final QuestGoalType goalType;
  final int difficulty; // 1 - 5
  final ActivityType activityType;
  final int estimatedMinutes;
  final bool isAutoDifficulty; // true = Auto, false = Manual
  final int expReward;
  final int goldReward;
  final int? awardedExp;
  final int? awardedGold;
  final String? dueDate; // ISO8601
  final bool isCompleted;
  final String? completedAt; // ISO8601
  final String createdAt; // ISO8601
  final int? habitStartMinute;
  final int? habitEndMinute;
  final int? habitTargetDays;

  const QuestModel({
    this.id,
    required this.title,
    this.description,
    this.category = QuestCategory.side,
    this.goalType = QuestGoalType.focus,
    this.difficulty = 1,
    this.activityType = ActivityType.mental,
    this.estimatedMinutes = 0,
    this.isAutoDifficulty = true,
    required this.expReward,
    required this.goldReward,
    this.awardedExp,
    this.awardedGold,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    this.habitStartMinute,
    this.habitEndMinute,
    this.habitTargetDays,
  }) : assert(difficulty >= 1 && difficulty <= 5,
            'difficulty must be between 1 and 5');

  QuestModel copyWith({
    int? id,
    String? title,
    String? description,
    QuestCategory? category,
    QuestGoalType? goalType,
    int? difficulty,
    ActivityType? activityType,
    int? estimatedMinutes,
    bool? isAutoDifficulty,
    int? expReward,
    int? goldReward,
    int? awardedExp,
    int? awardedGold,
    String? dueDate,
    bool? isCompleted,
    String? completedAt,
    String? createdAt,
    int? habitStartMinute,
    int? habitEndMinute,
    int? habitTargetDays,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      goalType: goalType ?? this.goalType,
      difficulty: difficulty ?? this.difficulty,
      activityType: activityType ?? this.activityType,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isAutoDifficulty: isAutoDifficulty ?? this.isAutoDifficulty,
      expReward: expReward ?? this.expReward,
      goldReward: goldReward ?? this.goldReward,
      awardedExp: awardedExp ?? this.awardedExp,
      awardedGold: awardedGold ?? this.awardedGold,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      habitStartMinute: habitStartMinute ?? this.habitStartMinute,
      habitEndMinute: habitEndMinute ?? this.habitEndMinute,
      habitTargetDays: habitTargetDays ?? this.habitTargetDays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'category': category.dbValue,
      'goal_type': goalType.dbValue,
      'difficulty': difficulty,
      'activity_type': activityType.dbValue,
      'estimated_minutes': estimatedMinutes,
      'is_auto_difficulty': isAutoDifficulty ? 1 : 0,
      'exp_reward': expReward,
      'gold_reward': goldReward,
      if (awardedExp != null) 'awarded_exp': awardedExp,
      if (awardedGold != null) 'awarded_gold': awardedGold,
      'due_date': dueDate,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt,
      'created_at': createdAt,
      'habit_start_minute': habitStartMinute,
      'habit_end_minute': habitEndMinute,
      'habit_target_days': habitTargetDays,
    };
  }

  factory QuestModel.fromMap(Map<String, dynamic> map) {
    return QuestModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: QuestCategoryX.fromDb(map['category'] as String),
      goalType: QuestGoalTypeX.fromDb(map['goal_type'] as String?),
      difficulty: map['difficulty'] as int? ?? 1,
      activityType: ActivityTypeX.fromDb(map['activity_type'] as String),
      estimatedMinutes: map['estimated_minutes'] as int? ?? 0,
      isAutoDifficulty: (map['is_auto_difficulty'] as int? ?? 1) == 1,
      expReward: map['exp_reward'] as int,
      goldReward: map['gold_reward'] as int,
      awardedExp: map['awarded_exp'] as int?,
      awardedGold: map['awarded_gold'] as int?,
      dueDate: map['due_date'] as String?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] as String?,
      createdAt: map['created_at'] as String,
      habitStartMinute: map['habit_start_minute'] as int?,
      habitEndMinute: map['habit_end_minute'] as int?,
      habitTargetDays: map['habit_target_days'] as int?,
    );
  }

  @override
  String toString() =>
      'QuestModel(id: $id, title: $title, category: ${category.dbValue}, '
      'difficulty: $difficulty, completed: $isCompleted)';
}
