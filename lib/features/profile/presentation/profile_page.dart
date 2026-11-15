import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile_failure.dart';
import '../models/profile_state.dart';
import '../providers/profile_providers.dart';
import '../../notifications/presentation/notification_status_tile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!(ref.read(profileProvider).asData?.value.isSaving ?? false)) {
          ref.invalidate(profileProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (ref.read(profileProvider).asData?.value.isSaving ?? false) return;
    ref.invalidate(profileProvider);
    try {
      await ref.read(profileProvider.future);
    } catch (_) {
      // La vista muestra el error de carga con la opción de reintento.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final authAction = ref.watch(authControllerProvider);
    final isHouseholdMember =
        ref.watch(currentUserProvider).asData?.value?.isHouseholdMember ??
        false;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CASA EN JUEGO',
              style: TextStyle(color: context.appColors.primary, fontSize: 10),
            ),
            SizedBox(height: 4),
            Text('Tu espacio', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  profile.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const SizedBox(
                      height: 250,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              color: context.appColors.primary,
                              size: 36,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              ProfileFailure.messageFor(error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _refresh,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (data) => _buildProfile(data, authAction.isLoading),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile.adaptive(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Modo oscuro'),
                      value: isDark,
                      onChanged: ref
                          .read(themeModeProvider.notifier)
                          .setDarkMode,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed:
                        authAction.isLoading ||
                            (profile.asData?.value.isSaving ?? false)
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                    icon: const Icon(Icons.logout, size: 20),
                    label: Text(
                      authAction.isLoading
                          ? 'Cerrando sesión…'
                          : 'Cerrar sesión',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appColors.error,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                  if (authAction.hasError)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        AuthFailure.messageFor(authAction.error!),
                        style: TextStyle(color: context.appColors.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Casa en Juego · Cada pequeño esfuerzo cuenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appColors.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isHouseholdMember
          ? const AppNavigationBar(selectedIndex: 3)
          : null,
    );
  }

  Widget _buildProfile(ProfileState data, bool isSigningOut) {
    final user = data.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: context.appColors.primaryContainer,
            child: Text(
              user.name.characters.take(2).toString().toUpperCase(),
              style: TextStyle(
                color: context.appColors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appColors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.appColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              !user.isHouseholdMember
                  ? 'Sin ciclo'
                  : user.isAdmin
                  ? 'Administrador'
                  : 'Miembro',
              style: TextStyle(color: context.appColors.primary, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (!user.isHouseholdMember)
          const Card(
            child: ListTile(
              leading: Icon(Icons.home_outlined),
              title: Text('Aún no tienes un ciclo'),
              subtitle: Text(
                'Tu cuenta ya está lista. La creación y el ingreso a ciclos estarán disponibles más adelante.',
              ),
            ),
          ),
        if (user.isAdmin) ...[
          Card(
            margin: EdgeInsets.zero,
            color: context.appColors.primaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.admin_panel_settings_outlined,
                color: context.appColors.primary,
              ),
              title: const Text('Cuidar del equipo'),
              subtitle: const Text('Administrar tareas y ciclos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: isSigningOut ? null : () => context.pushNamed('admin'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (user.isHouseholdMember)
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.history,
                    color: context.appColors.primary,
                  ),
                  title: const Text('Mi actividad'),
                  subtitle: Text(
                    'Tus solicitudes y sus resultados',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: isSigningOut
                      ? null
                      : () => context.pushNamed(
                          'activity',
                          queryParameters: {'from': 'profile'},
                        ),
                ),
                SwitchListTile.adaptive(
                  secondary: Icon(
                    Icons.notifications_none,
                    color: context.appColors.primary,
                  ),
                  title: const Text('Avisos de revisión'),
                  subtitle: Text(
                    data.isSaving
                        ? 'Guardando preferencia…'
                        : 'Preferencia para solicitudes y decisiones',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                  value: user.notificationsEnabled,
                  onChanged: data.isSaving || isSigningOut
                      ? null
                      : (enabled) => ref
                            .read(profileProvider.notifier)
                            .setNotifications(enabled),
                ),
                NotificationStatusTile(user: user),
              ],
            ),
          ),
        if (data.errorMessage != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              data.errorMessage!,
              style: TextStyle(color: context.appColors.error),
            ),
          ),
        ],
        if (user.isHouseholdMember) ...[
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: context.appColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text('Así sumamos en casa')),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Solo suman las tareas aprobadas del ciclo activo. Las pendientes y rechazadas no cuentan.',
                    style: TextStyle(
                      color: context.appColors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No puedes aprobar tus propias tareas. Cada nuevo ciclo empieza una nueva clasificación.',
                    style: TextStyle(
                      color: context.appColors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
