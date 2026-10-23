import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/push_notice.dart';

abstract interface class PushGateway {
  String get platform;
  Future<bool> permission({required bool request});
  Future<String?> getToken();
  Future<void> deleteToken();
  Stream<String> get tokenChanges;
  Stream<PushNotice> get foregroundNotices;
  Stream<PushNotice> get openedNotices;
  Future<PushNotice?> initialNotice();
}

Future<bool> initializePushNotifications() async {
  // La web sigue disponible para probar la app; esta integración es móvil.
  if (kIsWeb ||
      ![
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    return false;
  }
  try {
    await Firebase.initializeApp();
    return true;
  } catch (_) {
    // La ausencia de configuración no impide iniciar sesión ni registrar tareas.
    if (kDebugMode) {
      debugPrint('push.initialize: native configuration unavailable');
    }
    return false;
  }
}

class FirebasePushGateway implements PushGateway {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Future<bool> permission({required bool request}) async {
    final settings = request
        ? await _messaging.requestPermission()
        : await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() async {
    if (platform == 'ios' && await _messaging.getAPNSToken() == null) {
      return null;
    }
    final registered = Completer<String>();
    final subscription = _messaging.onRegistered.listen((id) {
      if (!registered.isCompleted) registered.complete(id);
    });
    try {
      // El SDK actual entrega el FID mediante un evento, incluso al volver a registrar.
      await _messaging.register().timeout(const Duration(seconds: 20));
      return await registered.future.timeout(const Duration(seconds: 20));
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> deleteToken() => _messaging.unregister();
  @override
  Stream<String> get tokenChanges => _messaging.onRegistered;
  Stream<PushNotice> _notices(Stream<RemoteMessage> messages) => messages
      .map((message) => PushNotice.fromData(message.data))
      .where((notice) => notice != null)
      .cast<PushNotice>();
  @override
  Stream<PushNotice> get foregroundNotices =>
      _notices(FirebaseMessaging.onMessage);
  @override
  Stream<PushNotice> get openedNotices =>
      _notices(FirebaseMessaging.onMessageOpenedApp);
  @override
  Future<PushNotice?> initialNotice() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushNotice.fromData(message.data);
  }
}
