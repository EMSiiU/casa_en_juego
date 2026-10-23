import 'dart:convert';
import 'dart:io';

import 'package:casa_en_juego/features/leaderboard/repositories/leaderboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseLeaderboardRepository repository;
  late List<Uri> requests;
  bool active = true;
  setUp(() async {
    active = true;
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      Object? body;
      switch (request.uri.path.split('/').last) {
        case 'seasons':
          body = active
              ? {
                  'id': 'season-id',
                  'name': 'Octubre 2026',
                  'start_date': '2026-10-01T00:00:00Z',
                }
              : null;
        case 'users':
          body = [
            {'id': 'member-id', 'name': 'Ana'},
            {'id': 'zero-id', 'name': 'Carlos'},
          ];
        case 'task_logs':
          final offset = int.parse(
            request.uri.queryParameters['offset'] ?? '0',
          );
          body = List.generate(
            offset == 0 ? 500 : 1,
            (index) => {
              'id': 'score-${offset + index}',
              'user_id': 'member-id',
              'task_id': 'task-id',
              'season_id': 'season-id',
              'status': 'approved',
              'points_snapshot': 3,
              'tasks': {'name': 'Barrer el cuarto', 'icon_name': 'broom'},
            },
          );
        default:
          body = null;
      }
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    repository = SupabaseLeaderboardRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('Ranking paginates approved cycle scores and includes members with zero points', () async {
    final data = await repository.loadLeaderboard();
    expect(data.totalPoints, 1503);
    expect(data.standingFor('zero-id')!.points, 0);
    final logRequests = requests
        .where((uri) => uri.path.endsWith('task_logs'))
        .toList();
    expect(logRequests.length, 2);
    expect(logRequests.last.queryParameters['offset'], '500');
    expect(
      logRequests.every(
        (uri) =>
            uri.queryParameters['status'] == 'eq.approved' &&
            uri.queryParameters['season_id'] == 'eq.season-id',
      ),
      isTrue,
    );
    expect(
      requests
          .singleWhere((uri) => uri.path.endsWith('users'))
          .queryParameters['select'],
      'id,name',
    );
  });
  test(
    'No active season does not invent rankings or query historical logs',
    () async {
      active = false;
      final data = await repository.loadLeaderboard();
      expect(data.season, isNull);
      expect(data.standings, isEmpty);
      expect(requests.length, 1);
    },
  );
}
