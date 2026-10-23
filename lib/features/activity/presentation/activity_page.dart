import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/activity_failure.dart';
import '../models/activity_filter.dart';
import '../models/activity_page_state.dart';
import '../providers/activity_providers.dart';
import 'widgets/activity_entry_card.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({
    super.key,
    this.showSubmissionNotice = false,
    this.fromProfile = false,
  });
  final bool fromProfile;
  final bool showSubmissionNotice;

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(activityProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(activityProvider);
    try {
      await ref.read(activityProvider.future);
    } catch (_) {
      // La pantalla presenta el error y permite volver a intentar la carga.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final filter = ref.watch(activityFilterProvider);
    final activity = ref.watch(activityProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          tooltip: widget.fromProfile ? 'Volver al perfil' : 'Volver a tareas',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(widget.fromProfile ? '/profile' : '/tasks'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user?.name.toUpperCase() ?? ''} · HISTORIAL',
              style: const TextStyle(color: AppTheme.primary, fontSize: 10),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mi actividad',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.showSubmissionNotice) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF26413E),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: Color(0xFF91D5C6),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Enviada a revisión. La decisión aparecerá aquí cuando se resuelva.',
                                      style: TextStyle(
                                        color: Color(0xFF91D5C6),
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final option in ActivityFilter.values)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      side: BorderSide.none,
                                      backgroundColor: AppTheme.surface,
                                      label: Text(option.label),
                                      selected: option == filter,
                                      showCheckmark: false,
                                      selectedColor: AppTheme.primary,
                                      labelStyle: TextStyle(
                                        color: option == filter
                                            ? AppTheme.background
                                            : const Color(0xFFB8B9C9),
                                        fontSize: 11,
                                      ),
                                      onSelected: (_) => ref
                                          .read(activityFilterProvider.notifier)
                                          .select(option),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Solicitudes recientes · Fechas en UTC−5',
                            style: TextStyle(
                              color: Color(0xFFB8B9C9),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  ...activity.when(
                    skipLoadingOnRefresh: false,
                    skipLoadingOnReload: false,
                    loading: () => [
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                    error: (error, stack) => [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                size: 36,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                ActivityFailure.messageFor(error),
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
                    ],
                    data: (data) => _buildHistory(data, filter),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: widget.fromProfile ? 3 : 0,
      ),
    );
  }

  List<Widget> _buildHistory(ActivityPageState data, ActivityFilter filter) {
    if (data.entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.history_outlined,
                  size: 40,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  filter == ActivityFilter.all
                      ? 'Aún no has registrado tareas'
                      : 'No tienes solicitudes ${filter.label.toLowerCase()}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Las tareas que registres y sus resultados aparecerán aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB8B9C9)),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: data.entries.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActivityEntryCard(
              key: ValueKey(data.entries[index].id),
              entry: data.entries[index],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              if (data.loadMoreError != null) ...[
                Text(
                  ActivityFailure.messageFor(data.loadMoreError!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              if (data.hasMore)
                TextButton(
                  onPressed: data.isLoadingMore
                      ? null
                      : () => ref.read(activityProvider.notifier).loadMore(),
                  child: data.isLoadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          data.loadMoreError == null
                              ? 'Cargar más'
                              : 'Reintentar carga',
                        ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Los puntos rechazados o pendientes no se suman.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
