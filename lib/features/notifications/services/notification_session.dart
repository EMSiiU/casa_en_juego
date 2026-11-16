import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/models/app_user.dart';
import '../models/push_notice.dart';
import '../repositories/notification_repository.dart';
import '../repositories/push_gateway.dart';

class NotificationSession {
  NotificationSession({
    required this.gateway,
    required this.repository,
    this.preferences,
  });
  final PushGateway gateway;
  final NotificationRepository repository;
  final SharedPreferencesAsync? preferences;
  final _statuses = StreamController<PushDeviceStatus>.broadcast();
  final Set<String> _tokens = {};
  String? _generalToken;
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
        if (user != null) {
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

  String _generalPreferenceKey(String userId) => 'push.general.$userId';

  Future<bool> generalNoticesEnabled(String userId) async =>
      await preferences?.getBool(_generalPreferenceKey(userId)) ?? false;

  Future<void> setGeneralNotices(String userId, bool enabled) {
    final next = _work.then((_) async {
      final store = preferences;
      if (_disposed || _user?.id != userId || store == null) {
        throw StateError('general_notices_unavailable');
      }
      final token = enabled && await gateway.permission(request: true)
          ? await gateway.getToken()
          : null;
      if (enabled && token == null) {
        throw StateError('general_notices_permission_or_registration');
      }
      if (_disposed || _user?.id != userId) {
        throw StateError('general_notices_unavailable');
      }
      final previousToken = _generalToken;
      await gateway.setGeneralNotices(enabled);
      _generalToken = token;
      try {
        await store.setBool(_generalPreferenceKey(userId), enabled);
      } catch (_) {
        // Restaura la suscripción si la preferencia local no se pudo guardar.
        await gateway.setGeneralNotices(!enabled);
        _generalToken = previousToken;
        rethrow;
      }
    });
    _work = next.catchError((Object _) {});
    return next;
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
      final privateEnabled =
          user != null && user.isHouseholdMember && user.notificationsEnabled;
      final generalEnabled =
          user != null &&
          await generalNoticesEnabled(user.id)
              .catchError((Object _) => _generalToken != null);
      if (_disposed || generation != _generation) return;
      if (!privateEnabled && !generalEnabled) {
        await _detach();
        _setStatus(PushDeviceStatus.disabled);
        return;
      }
      _setStatus(PushDeviceStatus.connecting);
      if (!await gateway.permission(
        request: requestPermission && privateEnabled,
      )) {
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
      try {
        if (generalEnabled && _generalToken != currentToken) {
          await gateway.setGeneralNotices(true);
          _generalToken = currentToken;
        } else if (!generalEnabled && _generalToken != null) {
          await gateway.setGeneralNotices(false);
          _generalToken = null;
        }
      } catch (_) {
        // La próxima sincronización reintenta el tema. Los avisos privados
        // aún pueden registrarse en Supabase.
      }
      if (privateEnabled) {
        _tokens.add(currentToken);
        await repository.register(
          token: currentToken,
          platform: gateway.platform,
        );
      }
      // Un error de red puede ocurrir después de guardar: se conserva el token para desvincularlo.
      for (final previous in _tokens.toList()) {
        if (!privateEnabled || previous != currentToken) {
          await repository.unregister(previous);
          _tokens.remove(previous);
        }
      }
      if (!_disposed && generation == _generation) {
        _setStatus(
          privateEnabled ? PushDeviceStatus.ready : PushDeviceStatus.disabled,
        );
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
    if (_generalToken != null) {
      try {
        await gateway.setGeneralNotices(false);
        _generalToken = null;
      } catch (_) {
        // La baja de FCM también revoca la recepción de la instalación.
      }
    }
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
    if (revokedAtProvider) {
      _tokens.clear();
      _generalToken = null;
    }
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
