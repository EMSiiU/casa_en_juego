import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile_failure.dart';
import '../models/profile_state.dart';
import '../providers/profile_providers.dart';

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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CASA EN JUEGO',
              style: TextStyle(color: AppTheme.primary, fontSize: 10),
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
                            const Icon(
                              Icons.person_off_outlined,
                              color: AppTheme.primary,
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
                      foregroundColor: const Color(0xFFF3A69B),
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                  if (authAction.hasError)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        AuthFailure.messageFor(authAction.error!),
                        style: const TextStyle(color: Color(0xFFF3A69B)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Casa en Juego · Cada pequeño esfuerzo cuenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigationBar(selectedIndex: 3),
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
            backgroundColor: const Color(0xFF39334F),
            child: Text(
              user.name.characters.take(2).toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
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
          style: const TextStyle(color: Color(0xFFB8B9C9)),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF39334F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.isAdmin ? 'Administrador' : 'Miembro',
              style: const TextStyle(color: AppTheme.primary, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (user.isAdmin) ...[
          Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF39334F),
            child: ListTile(
              leading: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppTheme.primary,
              ),
              title: const Text('Cuidar del equipo'),
              subtitle: const Text('Administrar tareas y ciclos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: isSigningOut ? null : () => context.pushNamed('admin'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: const Icon(Icons.history, color: AppTheme.primary),
                title: const Text('Mi actividad'),
                subtitle: const Text(
                  'Tus solicitudes y sus resultados',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB8B9C9)),
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
                secondary: const Icon(
                  Icons.notifications_none,
                  color: AppTheme.primary,
                ),
                title: const Text('Avisos de revisión'),
                subtitle: Text(
                  data.isSaving
                      ? 'Guardando preferencia…'
                      : 'Preferencia para solicitudes y decisiones',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB8B9C9),
                  ),
                ),
                value: user.notificationsEnabled,
                onChanged: data.isSaving || isSigningOut
                    ? null
                    : (enabled) => ref
                          .read(profileProvider.notifier)
                          .setNotifications(enabled),
              ),
            ],
          ),
        ),
        if (data.errorMessage != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              data.errorMessage!,
              style: const TextStyle(color: Color(0xFFF3A69B)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Card(
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
                      color: AppTheme.primary,
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
                    color: Color(0xFFB8B9C9),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'No puedes aprobar tus propias tareas. Cada nuevo ciclo empieza una nueva clasificación.',
                  style: TextStyle(
                    color: Color(0xFFB8B9C9),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
