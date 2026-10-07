class ActiveQuestTimer {
  final int questId;
  final String startedAt;
  final int targetDurationSeconds;
  final int remainingSeconds;
  final bool isPaused;
  final String? pausedAt;
  final String? completionError;

  const ActiveQuestTimer({
    required this.questId,
    required this.startedAt,
    required this.targetDurationSeconds,
    required this.remainingSeconds,
    this.isPaused = false,
    this.pausedAt,
    this.completionError,
  });

  double get progress => targetDurationSeconds <= 0
      ? 1
      : (1 - remainingSeconds / targetDurationSeconds).clamp(0.0, 1.0);

  ActiveQuestTimer copyWith({
    String? startedAt,
    int? targetDurationSeconds,
    int? remainingSeconds,
    bool? isPaused,
    String? pausedAt,
    bool clearPausedAt = false,
    String? completionError,
    bool clearCompletionError = false,
  }) {
    return ActiveQuestTimer(
      questId: questId,
      startedAt: startedAt ?? this.startedAt,
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
      completionError: clearCompletionError
          ? null
          : completionError ?? this.completionError,
    );
  }
}
