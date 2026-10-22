import 'dart:convert';
import 'dart:io';

import 'package:casa_en_juego/features/reviews/models/review_decision.dart';
import 'package:casa_en_juego/features/reviews/models/review_failure.dart';
import 'package:casa_en_juego/features/reviews/repositories/reviews_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseReviewsRepository repository;
  late List<Uri> requests;
  late List<Map<String, dynamic>> updates;
  bool conflict = false;

  setUp(() async {
    requests = [];
    updates = [];
    conflict = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'PATCH') {
        updates.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.write(
          jsonEncode(conflict ? null : {'id': 'request-id'}),
        );
      } else {
        final offset =
            int.tryParse(request.uri.queryParameters['offset'] ?? '0') ?? 0;
        request.response.write(
          jsonEncode(
            List.generate(
              offset == 0 ? 500 : 1,
              (index) => {
                'id': 'request-${offset + index}',
                'user_id': 'luis-id',
                'points_snapshot': 8,
                'requested_at': '2026-10-22T15:28:43Z',
                'requester': {'name': 'Luis'},
                'tasks': {'name': 'Limpiar el baño', 'icon_name': 'bathtub'},
                'seasons': {'name': 'Octubre 2026', 'status': 'active'},
              },
            ),
          ),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    repository = SupabaseReviewsRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('Inbox scopes pending requests to other users and active seasons, with pagination', () async {
    final inbox = await repository.loadInbox('ana-id');
    expect(inbox.length, 501);
    expect(inbox.first.pointsSnapshot, 8);
    expect(inbox.first.requesterName, 'Luis');
    expect(requests.length, 2);
    expect(requests.last.queryParameters['offset'], '500');
    for (final uri in requests) {
      expect(uri.queryParameters['user_id'], 'neq.ana-id');
      expect(uri.queryParameters['status'], 'eq.pending');
      expect(uri.queryParameters['seasons.status'], 'eq.active');
      expect(uri.queryParameters['select'], contains('seasons!inner'));
      expect(
        uri.queryParameters['select'],
        contains('users!task_logs_user_id_fkey'),
      );
    }
  });

  test(
    'A decision updates only status and requires an unresolved foreign request',
    () async {
      for (final decision in ReviewDecision.values) {
        await repository.resolve(
          requestId: 'request-id',
          reviewerId: 'ana-id',
          decision: decision,
        );
        expect(updates.last, {'status': decision.name});
        expect(requests.last.queryParameters['id'], 'eq.request-id');
        expect(requests.last.queryParameters['status'], 'eq.pending');
        expect(requests.last.queryParameters['user_id'], 'neq.ana-id');
      }
    },
  );

  test('No updated row is reported as conflict rather than success', () async {
    conflict = true;
    await expectLater(
      repository.resolve(
        requestId: 'request-id',
        reviewerId: 'ana-id',
        decision: ReviewDecision.approved,
      ),
      throwsA(isA<ReviewFailure>()),
    );
  });
}
