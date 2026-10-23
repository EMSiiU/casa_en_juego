import 'package:casa_en_juego/core/constants/task_log_status.dart';
import 'package:casa_en_juego/features/leaderboard/models/leaderboard_data.dart';
import 'package:casa_en_juego/features/leaderboard/models/leaderboard_member.dart';
import 'package:casa_en_juego/features/leaderboard/models/leaderboard_score.dart';
import 'package:casa_en_juego/features/leaderboard/repositories/leaderboard_repository.dart';

import 'fake_tasks_repository.dart';

const leaderboardMembers = [
  LeaderboardMember(id: 'member-id', name: 'Ana'),
  LeaderboardMember(id: 'luis-id', name: 'Luis'),
  LeaderboardMember(id: 'marta-id', name: 'Marta'),
  LeaderboardMember(id: 'leo-id', name: 'Leo'),
];

LeaderboardScore leaderboardScore({
  String id = 'score-id',
  String userId = 'member-id',
  int points = 8,
  String seasonId = 'season-id',
  TaskLogStatus status = TaskLogStatus.approved,
  String taskId = 'task-id',
  String taskName = 'Limpiar el baño',
}) => LeaderboardScore(
  id: id,
  userId: userId,
  taskId: taskId,
  seasonId: seasonId,
  status: status,
  pointsSnapshot: points,
  taskName: taskName,
  iconName: 'bathtub',
);

class FakeLeaderboardRepository implements LeaderboardRepository {
  LeaderboardData data = LeaderboardData(
    season: testSeason,
    members: leaderboardMembers,
    scores: [
      leaderboardScore(points: 42),
      leaderboardScore(id: 'luis', userId: 'luis-id', points: 36),
      leaderboardScore(id: 'marta', userId: 'marta-id', points: 27),
      leaderboardScore(id: 'leo', userId: 'leo-id', points: 18),
    ],
  );
  Object? error;
  @override
  Future<LeaderboardData> loadLeaderboard() async {
    if (error != null) throw error!;
    return data;
  }
}
