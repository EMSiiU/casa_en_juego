import 'dart:convert';
import 'dart:io';

import 'package:casa_en_juego/features/tasks/repositories/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseTasksRepository repository;
  late List<Uri> requests;
  late List<Map<String, dynamic>> inserts;
  bool activeSeason = true;

  setUp(() async {
    requests = [];
    inserts = [];
    activeSeason = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('get_task_submission_status')) {
        request.response.write(
          jsonEncode({
            'server_now': '2026-10-22T12:00:00Z',
            'resets_at': '2026-10-23T06:00:00Z',
            'blocked_task_ids': ['task-id'],
          }),
        );
        await request.response.close();
        return;
      }
      if (request.method == 'POST') {
        inserts.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = HttpStatus.created;
        await request.response.close();
        return;
      }
      Object? body;
      switch (request.uri.path.split('/').last) {
        case 'seasons':
          body = activeSeason
              ? {
                  'id': 'season-id',
                  'name': 'Octubre 2026',
                  'start_date': '2026-10-01T00:00:00Z',
                }
              : null;
        case 'tasks':
          body = [
            {
              'id': 'task-id',
              'name': 'Barrer el cuarto',
              'points': 99,
              'icon_name': 'broom',
              'is_active': true,
            },
          ];
        case 'task_logs':
          final offset =
              int.tryParse(request.uri.queryParameters['offset'] ?? '0') ?? 0;
          final length = offset == 0 ? 500 : 1;
          body = List.generate(
            length,
            (index) => {
              'id': 'log-${offset + index}',
              'user_id': 'member-id',
              'task_id': 'task-id',
              'season_id': 'season-id',
              'status': 'approved',
              'points_snapshot': 3,
              'requested_at': '2026-10-22T10:00:00Z',
              'tasks': {'name': 'Barrer el cuarto'},
            },
          );
        default:
          request.response.statusCode = HttpStatus.notFound;
          body = {'message': 'Not found'};
      }
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    repository = SupabaseTasksRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('Repository paginates history and uses snapshots instead of edited task points', () async {
    final dashboard = await repository.loadDashboard();
    expect(dashboard.logs.length, 501);
    expect(dashboard.approvedPointsFor('member-id'), 1503);
    expect(dashboard.tasks.single.points, 99);
    expect(dashboard.submissionStatus!.isBlocked('task-id'), isTrue);
    final logRequests = requests
        .where((uri) => uri.path.endsWith('task_logs'))
        .toList();
    expect(logRequests.length, 2);
    expect(logRequests.last.queryParameters['offset'], '500');
    expect(
      logRequests.every(
        (uri) => uri.queryParameters['season_id'] == 'eq.season-id',
      ),
      isTrue,
    );
    expect(
      requests
          .singleWhere((uri) => uri.path.endsWith('tasks'))
          .queryParameters['is_active'],
      'eq.true',
    );
  });

  test('Repository stops when there is no active season', () async {
    activeSeason = false;
    final dashboard = await repository.loadDashboard();
    expect(dashboard.season, isNull);
    expect(dashboard.tasks, isEmpty);
    expect(requests.length, 1);
  });

  test('Submission only sends foreign keys, leaving status, time and points to the server', () async {
    await repository.submitTask(
      userId: 'member-id',
      taskId: 'task-id',
      seasonId: 'season-id',
    );
    expect(inserts.single, {
      'user_id': 'member-id',
      'task_id': 'task-id',
      'season_id': 'season-id',
    });
  });
}
