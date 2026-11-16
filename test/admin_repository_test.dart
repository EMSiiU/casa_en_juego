import 'dart:convert';
import 'dart:io';

import 'package:casa_en_juego/features/admin/models/admin_failure.dart';
import 'package:casa_en_juego/features/admin/models/task_draft.dart';
import 'package:casa_en_juego/features/admin/repositories/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseAdminRepository repository;
  late List<({String method, Uri uri, Map<String, dynamic>? body})> requests;
  bool empty = false;
  setUp(() async {
    requests = [];
    empty = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      Map<String, dynamic>? values;
      if (request.method == 'POST' || request.method == 'PATCH') {
        values = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
      }
      requests.add((method: request.method, uri: request.uri, body: values));
      request.response.headers.contentType = ContentType.json;
      Object? body;
      if (request.uri.path.endsWith('/rpc/get_closed_cycle_catalog')) {
        body = [
          {
            'id': 'archived-task',
            'name': 'Barrer de nuevo',
            'points': 7,
            'icon_name': 'broom',
            'is_active': false,
            'is_daily_limited': true,
          },
        ];
      } else if (request.method != 'GET') {
        body = empty ? null : {'id': 'item-id'};
      } else {
        final params = request.uri.queryParameters;
        final offset = int.tryParse(params['offset'] ?? '0') ?? 0;
        switch (request.uri.path.split('/').last) {
          case 'seasons':
            if (params['status'] == 'eq.closed') {
              final closed = {
                'id': 'closed-id',
                'name': 'Septiembre 2026',
                'start_date': '2026-09-01T00:00:00Z',
                'end_date': '2026-09-30T00:00:00Z',
                'status': 'closed',
              };
              body = params.containsKey('id')
                  ? (empty ? null : closed)
                  : [closed];
            } else {
              body = {
                'id': 'season-id',
                'name': 'Octubre 2026',
                'start_date': '2026-10-01T00:00:00Z',
                'end_date': null,
                'status': 'active',
              };
            }
          case 'task_logs':
            body = List.generate(
              offset == 0 ? 500 : 1,
              (index) => {
                'id': 'log-${offset + index}',
                'user_id': 'member-id',
                'status': 'approved',
                'points_snapshot': 3,
                'requester_name_snapshot': 'Ana',
              },
            );
          case 'tasks':
            final task = {
              'id': 'task-id',
              'name': 'Barrer',
              'points': 3,
              'icon_name': 'broom',
              'is_active': false,
            };
            body = params.containsKey('id') ? (empty ? null : task) : [task];
        }
      }
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    repository = SupabaseAdminRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'Dashboard paginates cycle logs and the catalog includes inactive tasks',
    () async {
      final data = await repository.loadDashboard();
      expect(data.active!.approvedPoints, 1503);
      expect(data.active!.participants, 1);
      final logs = requests
          .where((request) => request.uri.path.endsWith('task_logs'))
          .toList();
      expect(logs.length, 2);
      expect(logs.last.uri.queryParameters['offset'], '500');
      expect(
        logs.every(
          (request) =>
              request.uri.queryParameters['season_id'] == 'eq.season-id',
        ),
        isTrue,
      );
      final tasks = await repository.loadTasks();
      expect(tasks.single.isActive, isFalse);
      expect(
        requests.last.uri.queryParameters.containsKey('is_active'),
        isFalse,
      );
    },
  );

  test('Task creation and editing never rewrite task logs', () async {
    final draft = TaskDraft(
      name: ' Barrer ',
      points: 12,
      iconName: 'broom',
      isActive: false,
    );
    await repository.saveTask(draft: draft);
    await repository.saveTask(id: 'task-id', draft: draft);
    expect(requests.map((request) => request.method), ['POST', 'PATCH']);
    expect(
      requests.every((request) => request.uri.path.endsWith('tasks')),
      isTrue,
    );
    expect(requests.first.body, {
      'name': 'Barrer',
      'points': 12,
      'icon_name': 'broom',
      'is_active': false,
      'is_daily_limited': false,
    });
    expect(requests.last.uri.queryParameters['id'], 'eq.task-id');
  });

  test(
    'Closed cycle results load archived tasks through the cycle RPC',
    () async {
      expect((await repository.loadClosedCycles()).single.id, 'closed-id');
      final summary = await repository.loadClosedCycle('closed-id');
      expect(summary.season.name, 'Septiembre 2026');
      expect(summary.archivedCatalog.single.name, 'Barrer de nuevo');
      expect(summary.archivedCatalog.single.isActive, isFalse);
      expect(summary.archivedCatalog.single.isDailyLimited, isTrue);
      expect(summary.results.single.points, 1503);
      final rpc = requests.singleWhere(
        (request) => request.uri.path.endsWith('/rpc/get_closed_cycle_catalog'),
      );
      expect(rpc.body, {'p_season_id': 'closed-id'});
      expect(rpc.uri.queryParameters['order'], startsWith('name.'));
    },
  );

  test('Closing changes only the status of an active cycle', () async {
    await repository.closeSeason('season-id');
    expect(requests.single.body, {'status': 'closed'});
    expect(requests.single.uri.queryParameters['id'], 'eq.season-id');
    expect(requests.single.uri.queryParameters['status'], 'eq.active');
    expect(requests.single.uri.path.endsWith('seasons'), isTrue);
  });

  test('Zero-row updates are explicit conflicts', () async {
    empty = true;
    await expectLater(
      repository.closeSeason('season-id'),
      throwsA(isA<AdminFailure>()),
    );
    await expectLater(
      repository.saveTask(
        id: 'task-id',
        draft: TaskDraft(
          name: 'Task',
          points: 3,
          iconName: 'broom',
          isActive: true,
        ),
      ),
      throwsA(isA<AdminFailure>()),
    );
  });
}
