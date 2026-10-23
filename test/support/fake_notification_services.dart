import 'dart:async';

import 'package:casa_en_juego/features/notifications/models/push_notice.dart';
import 'package:casa_en_juego/features/notifications/repositories/notification_repository.dart';
import 'package:casa_en_juego/features/notifications/repositories/push_gateway.dart';

class FakePushGateway implements PushGateway {
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<PushNotice>.broadcast();
  final opened = StreamController<PushNotice>.broadcast();
  bool allowed = true;
  String? token = 'device-token-001';
  PushNotice? initial;
  Object? deleteError;
  int permissionRequests = 0;
  int deletes = 0;
  @override
  String get platform => 'android';
  @override
  Future<bool> permission({required bool request}) async {
    if (request) permissionRequests++;
    return allowed;
  }

  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> deleteToken() async {
    deletes++;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<PushNotice> get foregroundNotices => foreground.stream;
  @override
  Stream<PushNotice> get openedNotices => opened.stream;
  @override
  Future<PushNotice?> initialNotice() async => initial;
  Future<void> close() async {
    await tokens.close();
    await foreground.close();
    await opened.close();
  }
}

class FakeNotificationRepository implements NotificationRepository {
  final registered = <String>[];
  final unregistered = <String>[];
  Completer<void>? pendingRegister;
  Object? unregisterError;
  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    registered.add(token);
    await pendingRegister?.future;
  }

  @override
  Future<void> unregister(String token) async {
    if (unregisterError != null) throw unregisterError!;
    unregistered.add(token);
  }
}
