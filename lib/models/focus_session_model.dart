class FocusSessionModel {
  final int? id;
  final String startedAt; // ISO8601

  const FocusSessionModel({this.id, required this.startedAt});

  FocusSessionModel copyWith({int? id, String? startedAt}) {
    return FocusSessionModel(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'started_at': startedAt};
  }

  factory FocusSessionModel.fromMap(Map<String, dynamic> map) {
    return FocusSessionModel(
      id: map['id'] as int?,
      startedAt: map['started_at'] as String,
    );
  }

  @override
  String toString() => 'FocusSessionModel(id: $id, startedAt: $startedAt)';
}
