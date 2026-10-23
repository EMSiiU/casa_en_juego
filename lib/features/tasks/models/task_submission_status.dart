class TaskSubmissionStatus {
  TaskSubmissionStatus({
    required Set<String> blockedTaskIds,
    required this.resetsAfter,
  }) : blockedTaskIds = Set.unmodifiable(blockedTaskIds);

  factory TaskSubmissionStatus.fromJson(Map<String, dynamic> json) =>
      TaskSubmissionStatus(
        blockedTaskIds: (json['blocked_task_ids'] as List)
            .cast<String>()
            .toSet(),
        // El reloj del dispositivo no determina el cambio de día.
        resetsAfter: DateTime.parse(json['resets_at'] as String)
            .difference(DateTime.parse(json['server_now'] as String)),
      );

  final Set<String> blockedTaskIds;
  final Duration resetsAfter;
  bool isBlocked(String taskId) => blockedTaskIds.contains(taskId);
}
