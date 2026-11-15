import 'dart:async';

import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/profile/repositories/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  AppUser user = const AppUser(
    id: 'member-id',
    name: 'Ana',
    email: 'ana@familia.es',
    role: UserRole.sibling,
    notificationsEnabled: true,
  );
  Object? loadError;
  Object? saveError;
  Completer<void>? pendingSave;
  int saveCalls = 0;
  String? savedUserId;
  String? savedName;
  Future<void> Function(String, DateTime)? onCreateCycle;

  @override
  Future<void> createFirstCycle({
    required String name,
    required DateTime plannedEndDate,
  }) async {
    await onCreateCycle!(name, plannedEndDate);
  }

  @override
  Future<String> rename(String name) async {
    if (pendingSave != null) await pendingSave!.future;
    if (saveError != null) throw saveError!;
    savedName = name;
    user = user.withName(name);
    return name;
  }

  @override
  Future<AppUser> loadProfile(String userId) async {
    if (loadError != null) throw loadError!;
    return user;
  }

  @override
  Future<AppUser> setNotifications({
    required String userId,
    required bool enabled,
  }) async {
    saveCalls++;
    savedUserId = userId;
    if (pendingSave != null) await pendingSave!.future;
    if (saveError != null) throw saveError!;
    user = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      notificationsEnabled: enabled,
      isHouseholdMember: user.isHouseholdMember,
      avatarUrl: user.avatarUrl,
    );
    return user;
  }
}
