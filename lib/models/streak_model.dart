class StreakModel {
  final int currentStreak;
  final DateTime? lastCompletedDate;
  final bool isFrozen;
  final int missedDaysCount;

  const StreakModel({
    this.currentStreak = 0,
    this.lastCompletedDate,
    this.isFrozen = false,
    this.missedDaysCount = 0,
  });

  StreakModel copyWith({
    int? currentStreak,
    DateTime? lastCompletedDate,
    bool? isFrozen,
    int? missedDaysCount,
  }) {
    return StreakModel(
      currentStreak: currentStreak ?? this.currentStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      isFrozen: isFrozen ?? this.isFrozen,
      missedDaysCount: missedDaysCount ?? this.missedDaysCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentStreak': currentStreak,
    'lastCompletedDate': lastCompletedDate?.toIso8601String(),
    'isFrozen': isFrozen,
    'missedDaysCount': missedDaysCount,
  };
}