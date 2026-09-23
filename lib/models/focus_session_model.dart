class FocusSessionModel {
  final int? id;
  final String startedAt; // ISO8601
  final int targetDuration; // seconds

  const FocusSessionModel({
    this.id,
    required this.startedAt,
    required this.targetDuration,
  });

  FocusSessionModel copyWith({
    int? id,
    String? startedAt,
    int? targetDuration,
  }) {
    return FocusSessionModel(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      targetDuration: targetDuration ?? this.targetDuration,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'started_at': startedAt,
      'target_duration': targetDuration,
    };
  }

  factory FocusSessionModel.fromMap(Map<String, dynamic> map) {
    return FocusSessionModel(
      id: map['id'] as int?,
      startedAt: map['started_at'] as String,
      targetDuration: map['target_duration'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'FocusSessionModel(id: $id, startedAt: $startedAt, targetDuration: $targetDuration)';
}
