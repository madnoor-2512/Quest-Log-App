class SubTaskModel {
  final int? id;
  final int questId;
  final String title;
  final bool isCompleted;

  const SubTaskModel({
    this.id,
    required this.questId,
    required this.title,
    this.isCompleted = false,
  });

  SubTaskModel copyWith({
    int? id,
    int? questId,
    String? title,
    bool? isCompleted,
  }) {
    return SubTaskModel(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'quest_id': questId,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory SubTaskModel.fromMap(Map<String, dynamic> map) {
    return SubTaskModel(
      id: map['id'] as int?,
      questId: map['quest_id'] as int,
      title: map['title'] as String,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
    );
  }

  @override
  String toString() =>
      'SubTaskModel(id: $id, questId: $questId, title: $title, completed: $isCompleted)';
}
