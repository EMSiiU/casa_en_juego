import 'dart:async';

import '../../auth/models/app_user.dart';
import '../models/push_notice.dart';
import '../repositories/notification_repository.dart';
import '../repositories/push_gateway.dart';

class NotificationSession {
  NotificationSession({required this.gateway, required this.repository});
  final PushGateway gateway;
  final NotificationRepository repository;
  final _statuses = StreamController<PushDeviceStatus>.broadcast();
  final Set<String> _tokens = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void> _work = Future.value();
  AppUser? _user;
  AppUser? get user => _user;
  int _generation = 0;
  bool _disposed = false;
  bool _started = false;
  PushDeviceStatus status = PushDeviceStatus.disabled;
  Stream<PushDeviceStatus> get statuses => _statuses.stream;
  void Function(PushNotice notice, bool opened)? onNotice;

  void _setStatus(PushDeviceStatus value) {
    if (_disposed) return;
    status = value;
    _statuses.add(value);
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscriptions.addAll([
      gateway.tokenChanges.listen((token) {
        final user = _user;
        if (user != null && user.notificationsEnabled) {
          unawaited(syncUser(user, requestPermission: false, token: token));
        }
      }, onError: (Object _) => _setStatus(PushDeviceStatus.error)),
      gateway.foregroundNotices.listen(
        (notice) => onNotice?.call(notice, false),
      ),
      gateway.openedNotices.listen((notice) => onNotice?.call(notice, true)),
    ]);
    unawaited(_readInitialNotice());
  }

  Future<void> _readInitialNotice() async {
    try {
      final notice = await gateway.initialNotice();
      if (!_disposed && notice != null) onNotice?.call(notice, true);
    } catch (_) {
      _setStatus(PushDeviceStatus.error);
    }
  }

  Future<void> syncUser(
    AppUser? user, {
    bool requestPermission = true,
    String? token,
  }) {
    _user = user;
    final generation = ++_generation;
    // Serializa cambios de cuenta, renovación de token y cierre de sesión.
    final next = _work.then((_) async {
      if (_disposed || generation != _generation) return;
      if (user == null || !user.notificationsEnabled) {
        await _detach();
        _setStatus(PushDeviceStatus.disabled);
        return;
      }
      _setStatus(PushDeviceStatus.connecting);
      if (!await gateway.permission(request: requestPermission)) {
        await _detach();
        _setStatus(PushDeviceStatus.denied);
        return;
      }
      if (_disposed || generation != _generation) return;
      final currentToken = token ?? await gateway.getToken();
      if (currentToken == null) {
        _setStatus(PushDeviceStatus.error);
        return;
      }
      if (_disposed || generation != _generation) return;
      _tokens.add(currentToken);
      await repository.register(
        token: currentToken,
        platform: gateway.platform,
      );
      // Un error de red puede ocurrir después de guardar: se conserva el token para desvincularlo.
      for (final previous in _tokens.toList()) {
        if (previous != currentToken) {
          await repository.unregister(previous);
          _tokens.remove(previous);
        }
      }
      if (!_disposed && generation == _generation) {
        _setStatus(PushDeviceStatus.ready);
      }
    });
    _work = next.catchError((Object _) => _setStatus(PushDeviceStatus.error));
    return _work;
  }

  Future<void> disconnect() {
    _user = null;
    _generation++;
    final next = _work.then((_) => _detach());
    // Se propaga al cierre de sesión si no se pudo revocar por ninguna vía.
    _work = next.catchError((Object _) => _setStatus(PushDeviceStatus.error));
    return next;
  }

  Future<void> _detach() async {
    final hadTokens = _tokens.isNotEmpty;
    var revokedAtProvider = false;
    try {
      await gateway.deleteToken();
      revokedAtProvider = true;
    } catch (_) {
      // Si FCM falla, la eliminación en Supabase impide nuevos envíos.
    }
    Object? failure;
    for (final token in _tokens.toList()) {
      try {
        await repository.unregister(token);
        _tokens.remove(token);
      } catch (error) {
        failure = error;
      }
    }
    if (!revokedAtProvider && (failure != null || !hadTokens)) {
      throw StateError('push_detach_failed');
    }
    if (revokedAtProvider) _tokens.clear();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    onNotice = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_statuses.close());
  }
}
