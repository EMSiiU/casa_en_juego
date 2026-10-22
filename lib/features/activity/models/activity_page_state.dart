import 'activity_entry.dart';

class ActivityPageState {
  ActivityPageState({
    required List<ActivityEntry> entries,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  }) : entries = List.unmodifiable(entries);

  final List<ActivityEntry> entries;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
}
