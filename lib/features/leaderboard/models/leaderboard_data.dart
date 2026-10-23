import '../../tasks/models/season.dart';
import '../../../core/constants/task_log_status.dart';
import 'leaderboard_member.dart';
import 'leaderboard_score.dart';

class LeaderboardStanding {
  const LeaderboardStanding({
    required this.member,
    required this.points,
    required this.position,
  });
  final LeaderboardMember member;
  final int points;
  final int? position;
}

class TaskContribution {
  const TaskContribution({
    required this.taskId,
    required this.taskName,
    required this.iconName,
    required this.points,
    required this.completedCount,
  });
  final String taskId;
  final String taskName;
  final String iconName;
  final int points;
  final int completedCount;
}

class LeaderboardData {
  LeaderboardData({
    required this.season,
    required List<LeaderboardMember> members,
    required List<LeaderboardScore> scores,
  }) : members = List.unmodifiable(members),
       scores = List.unmodifiable(scores);
  final Season? season;
  final List<LeaderboardMember> members;
  final List<LeaderboardScore> scores;

  Iterable<LeaderboardScore> get _approvedScores => scores.where(
    (score) =>
        season != null &&
        score.seasonId == season!.id &&
        score.status == TaskLogStatus.approved,
  );

  List<LeaderboardStanding> get standings {
    final totals = <String, int>{};
    final seen = <String>{};
    for (final score in _approvedScores) {
      if (!seen.add(score.id)) continue;
      totals.update(
        score.userId,
        (value) => value + score.pointsSnapshot,
        ifAbsent: () => score.pointsSnapshot,
      );
    }
    final sorted = members.toList()
      ..sort((a, b) {
        final byPoints = (totals[b.id] ?? 0).compareTo(totals[a.id] ?? 0);
        if (byPoints != 0) return byPoints;
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName == 0 ? a.id.compareTo(b.id) : byName;
      });
    // Los empates comparten posición (1, 1, 3). Cero puntos no otorga un puesto.
    return sorted.map((member) {
      final points = totals[member.id] ?? 0;
      return LeaderboardStanding(
        member: member,
        points: points,
        position: points == 0
            ? null
            : 1 +
                  members
                      .where((other) => (totals[other.id] ?? 0) > points)
                      .length,
      );
    }).toList();
  }

  int get totalPoints =>
      standings.fold(0, (total, standing) => total + standing.points);

  LeaderboardStanding? standingFor(String userId) {
    for (final standing in standings) {
      if (standing.member.id == userId) return standing;
    }
    return null;
  }

  List<TaskContribution> bestTasksFor(String userId) {
    final grouped = <String, TaskContribution>{};
    final seen = <String>{};
    for (final score in _approvedScores.where(
      (score) => score.userId == userId,
    )) {
      if (!seen.add(score.id)) continue;
      final previous = grouped[score.taskId];
      grouped[score.taskId] = TaskContribution(
        taskId: score.taskId,
        taskName: score.taskName,
        iconName: score.iconName,
        points: (previous?.points ?? 0) + score.pointsSnapshot,
        completedCount: (previous?.completedCount ?? 0) + 1,
      );
    }
    return (grouped.values.toList()..sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          return byPoints == 0 ? a.taskId.compareTo(b.taskId) : byPoints;
        }))
        .take(3)
        .toList();
  }
}
