import 'quest_enums.dart';

class QuestModel {
  final int? id;
  final String title;
  final String? description;
  final QuestCategory category;
  final int difficulty; // 1 - 5
  final ActivityType activityType;
  final int estimatedMinutes;
  final bool isAutoDifficulty; // true = Auto, false = Manual
  final int expReward;
  final int goldReward;
  final String? dueDate; // ISO8601
  final bool isCompleted;
  final String? completedAt; // ISO8601
  final String createdAt; // ISO8601

  const QuestModel({
    this.id,
    required this.title,
    this.description,
    this.category = QuestCategory.side,
    this.difficulty = 1,
    this.activityType = ActivityType.mental,
    this.estimatedMinutes = 0,
    this.isAutoDifficulty = true,
    required this.expReward,
    required this.goldReward,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  }) : assert(difficulty >= 1 && difficulty <= 5,
            'difficulty must be between 1 and 5');

  QuestModel copyWith({
    int? id,
    String? title,
    String? description,
    QuestCategory? category,
    int? difficulty,
    ActivityType? activityType,
    int? estimatedMinutes,
    bool? isAutoDifficulty,
    int? expReward,
    int? goldReward,
    String? dueDate,
    bool? isCompleted,
    String? completedAt,
    String? createdAt,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      activityType: activityType ?? this.activityType,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isAutoDifficulty: isAutoDifficulty ?? this.isAutoDifficulty,
      expReward: expReward ?? this.expReward,
      goldReward: goldReward ?? this.goldReward,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'category': category.dbValue,
      'difficulty': difficulty,
      'activity_type': activityType.dbValue,
      'estimated_minutes': estimatedMinutes,
      'is_auto_difficulty': isAutoDifficulty ? 1 : 0,
      'exp_reward': expReward,
      'gold_reward': goldReward,
      'due_date': dueDate,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt,
      'created_at': createdAt,
    };
  }

  factory QuestModel.fromMap(Map<String, dynamic> map) {
    return QuestModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: QuestCategoryX.fromDb(map['category'] as String),
      difficulty: map['difficulty'] as int? ?? 1,
      activityType: ActivityTypeX.fromDb(map['activity_type'] as String),
      estimatedMinutes: map['estimated_minutes'] as int? ?? 0,
      isAutoDifficulty: (map['is_auto_difficulty'] as int? ?? 1) == 1,
      expReward: map['exp_reward'] as int,
      goldReward: map['gold_reward'] as int,
      dueDate: map['due_date'] as String?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  @override
  String toString() =>
      'QuestModel(id: $id, title: $title, category: ${category.dbValue}, '
      'difficulty: $difficulty, completed: $isCompleted)';
}
