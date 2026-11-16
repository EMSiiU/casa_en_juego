import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_page_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/widgets/account_menu.dart';
import '../models/review_decision.dart';
import '../models/review_failure.dart';
import '../providers/reviews_providers.dart';
import 'widgets/review_request_card.dart';

class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    if (ref.read(reviewActionProvider).isBusy) return;
    ref.read(reviewActionProvider.notifier).clearError();
    ref.invalidate(reviewsInboxProvider);
    try {
      await ref.read(reviewsInboxProvider.future);
    } catch (_) {
      // La bandeja muestra el error y permite reintentar.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(reviewsInboxProvider);
    final action = ref.watch(reviewActionProvider);
    final count = inbox.asData?.value.length;
    return Scaffold(
      appBar: AppPageBar(
        subtitle: count == null ? 'SOLICITUDES DE OTROS' : '$count POR REVISAR',
        title: 'Revisiones',
        trailing: const AccountMenu(),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.appColors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: context.appColors.primary,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Aquí revisas a otros miembros. Tus propias tareas solo las puede validar otra persona.',
                                    style: TextStyle(
                                      color: context.appColors.onSurfaceVariant,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (action.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                action.errorMessage!,
                                style: TextStyle(
                                  color: context.appColors.error,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _refresh(ref),
                              child: const Text('Actualizar bandeja'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ...inbox.when(
                    skipLoadingOnRefresh: false,
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
                              Icon(
                                Icons.cloud_off_outlined,
                                size: 36,
                                color: context.appColors.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                ReviewFailure.messageFor(error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _refresh(ref),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    data: (requests) => requests.isEmpty
                        ? [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.task_alt,
                                      color: context.appColors.primary,
                                      size: 42,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No hay solicitudes por revisar',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Aquí aparecerán las tareas pendientes de otros miembros del ciclo activo.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            context.appColors.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        : [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverList.builder(
                                itemCount: requests.length,
                                itemBuilder: (context, index) {
                                  final request = requests[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: ReviewRequestCard(
                                      key: ValueKey(request.id),
                                      request: request,
                                      disabled: action.isBusy,
                                      isProcessing: action.busyId == request.id,
                                      onDecision: (decision) async {
                                        final success = await ref
                                            .read(reviewActionProvider.notifier)
                                            .resolve(request.id, decision);
                                        if (context.mounted && success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              duration: const Duration(
                                                seconds: 3,
                                              ),
                                              persist: false,
                                              content: Text(
                                                decision ==
                                                        ReviewDecision.approved
                                                    ? 'Solicitud aprobada.'
                                                    : 'Solicitud rechazada.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                                // child: Text(
                                //   'Fechas en UTC−5. El solicitante verá el resultado en Mi actividad.',
                                //   style: TextStyle(
                                //     color: context.appColors.onSurfaceVariant,
                                //     fontSize: 11,
                                //     height: 1.5,
                                //   ),
                                // ),
                              ),
                            ),
                          ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigationBar(selectedIndex: 2),
    );
  }
}
