import 'dart:convert';
import 'dart:io';

import 'package:casa_en_juego/features/activity/models/activity_filter.dart';
import 'package:casa_en_juego/features/activity/repositories/activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseActivityRepository repository;
  late List<Uri> requests;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      final offset = int.parse(request.uri.queryParameters['offset'] ?? '0');
      request.response.write(
        jsonEncode(
          List.generate(
            offset == 0 ? 21 : 2,
            (index) => {
              'id': 'entry-${offset + index}',
              'user_id': 'member-id',
              'status': 'approved',
              'points_snapshot': 8,
              'requested_at': '2026-10-22T15:42:18Z',
              'resolved_at': '2026-10-22T16:00:00Z',
              'tasks': {'name': 'Limpiar el baño'},
              'seasons': {'name': 'Septiembre 2026', 'status': 'closed'},
              'reviewer': {'name': 'Luis'},
            },
          ),
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    repository = SupabaseActivityRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('Activity queries the current user and resolves the reviewer through its foreign key', () async {
    final page = await repository.loadPage(
      userId: 'member-id',
      filter: ActivityFilter.all,
      offset: 0,
      limit: 20,
    );
    final params = requests.single.queryParameters;
    expect(params['user_id'], 'eq.member-id');
    expect(params.containsKey('status'), isFalse);
    expect(params.containsKey('season_id'), isFalse);
    expect(
      params['select'],
      contains('reviewer:users!task_logs_approved_by_fkey(name)'),
    );
    expect(params['order'], startsWith('requested_at.desc'));
    expect(params['order'], contains(',id.desc'));
    expect(page.entries.length, 20);
    expect(page.hasMore, isTrue);
    expect(page.entries.first.reviewerName, 'Luis');
    expect(page.entries.first.isSeasonClosed, isTrue);
    expect(page.entries.first.awardedPoints, 8);
  });

  test('Status filters and page ranges are sent to Supabase', () async {
    for (final filter in ActivityFilter.values.where(
      (filter) => filter.status != null,
    )) {
      final page = await repository.loadPage(
        userId: 'member-id',
        filter: filter,
        offset: 20,
        limit: 20,
      );
      final params = requests.last.queryParameters;
      expect(params['status'], 'eq.${filter.status!.name}');
      expect(params['offset'], '20');
      expect(params['limit'], '21');
      expect(page.hasMore, isFalse);
      expect(page.entries.length, 2);
    }
  });
}
