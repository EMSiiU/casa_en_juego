import 'dart:async';

import 'package:casa_en_juego/core/constants/task_log_status.dart';
import 'package:casa_en_juego/features/activity/models/activity_entry.dart';
import 'package:casa_en_juego/features/activity/models/activity_filter.dart';
import 'package:casa_en_juego/features/activity/models/activity_page_state.dart';
import 'package:casa_en_juego/features/activity/repositories/activity_repository.dart';

ActivityEntry activityEntry({
  String id = 'activity-id',
  TaskLogStatus status = TaskLogStatus.pending,
  bool closed = false,
  String userId = 'member-id',
}) => ActivityEntry(
  id: id,
  userId: userId,
  taskName: switch (status) {
    TaskLogStatus.pending => 'Barrer el cuarto',
    TaskLogStatus.approved => 'Limpiar el baño',
    TaskLogStatus.rejected => 'Sacar la basura',
  },
  seasonName: closed ? 'Septiembre 2026' : 'Octubre 2026',
  isSeasonClosed: closed,
  status: status,
  pointsSnapshot: status == TaskLogStatus.approved ? 8 : 3,
  requestedAt: DateTime.utc(2026, 10, 22, 15, 42, 18),
  reviewerName: status == TaskLogStatus.pending ? null : 'Luis',
  resolvedAt: status == TaskLogStatus.pending
      ? null
      : DateTime.utc(2026, 10, 22, 16),
);

class FakeActivityRepository implements ActivityRepository {
  List<ActivityEntry> entries = [
    activityEntry(),
    activityEntry(id: 'approved', status: TaskLogStatus.approved),
    activityEntry(id: 'rejected', status: TaskLogStatus.rejected),
  ];
  Object? loadError;
  Object? loadMoreError;
  Completer<ActivityPageState>? pendingPage;
  final calls = <({String userId, ActivityFilter filter, int offset})>[];

  @override
  Future<ActivityPageState> loadPage({
    required String userId,
    required ActivityFilter filter,
    required int offset,
    required int limit,
  }) async {
    calls.add((userId: userId, filter: filter, offset: offset));
    if (offset > 0 && pendingPage != null) return pendingPage!.future;
    if (offset > 0 && loadMoreError != null) throw loadMoreError!;
    if (loadError != null) throw loadError!;
    final visible = entries
        .where(
          (entry) =>
              entry.userId == userId &&
              (filter.status == null || entry.status == filter.status),
        )
        .toList();
    return ActivityPageState(
      entries: visible.skip(offset).take(limit).toList(),
      hasMore: visible.length > offset + limit,
    );
  }
}
