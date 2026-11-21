import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_page_bar.dart';
import '../../auth/presentation/widgets/account_menu.dart';
import '../providers/family_payment_provider.dart';
import '../repositories/family_payment_repository.dart';

class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = ref.watch(familyPaymentProvider);
    final supported = ref.watch(familyPaymentSupportedProvider);
    final planState = ref.watch(currentPlanProvider);
    final plan = planState.asData?.value;
    ref.listen(familyPaymentProvider, (previous, next) {
      if (next.isLoading || identical(previous, next)) return;
      final error = next.error;
      final result = next.asData?.value;
      final message = next.hasError
          ? error is FamilyPaymentFailure
                ? error.message
                : 'No pudimos completar el pago de prueba.'
          : switch (result) {
              FamilyPaymentResult.completed => 'Pago de prueba completado. Puedes ver la suscripción en Stripe.',
              FamilyPaymentResult.canceled => 'Pago cancelado.',
              FamilyPaymentResult.alreadyActive =>
                'Ya tienes una suscripción Familia de prueba activa en Stripe.',
              null => null,
            };
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
    return Scaffold(
      appBar: const AppPageBar(title: 'Planes', trailing: AccountMenu()),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Catálogo de demostración para probar los pagos, no es real :)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (planState.isLoading) ...[
                  const Text('Consultando tu plan…'),
                  const SizedBox(height: 16),
                ],
                if (planState.hasError) ...[
                  const Text('No pudimos consultar tu plan.'),
                  TextButton(
                    onPressed: () => ref.invalidate(currentPlanProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
                if (!supported) ...[
                  const Text(
                    'El pago de prueba de Familia está disponible en Android.',
                  ),
                  const SizedBox(height: 16),
                ],
                _PlanCard(
                  name: 'Casa',
                  price: 'Gratis',
                  benefits: [
                    'Un ciclo activo',
                    'Tareas personalizadas',
                    'Historial de actividad',
                  ],
                  buttonLabel: plan == AccountPlan.casa
                      ? 'Plan actual'
                      : 'Gratis',
                ),
                const SizedBox(height: 16),
                _PlanCard(
                  name: 'Familia',
                  price: '\$39 MXN / mes',
                  benefits: [
                    'Hasta tres ciclos simultáneos',
                    'Para casa, escuela y actividades familiares',
                  ],
                  buttonLabel: plan == AccountPlan.familia
                      ? 'Plan actual'
                      : payment.isLoading
                      ? 'Preparando pago…'
                      : 'Probar pago',
                  onPressed:
                      !supported ||
                          payment.isLoading ||
                          planState.isLoading ||
                          planState.hasError ||
                          plan == null ||
                          plan == AccountPlan.familia
                      ? null
                      : () =>
                            ref.read(familyPaymentProvider.notifier).checkout(),
                ),
                const SizedBox(height: 16),
                _PlanCard(
                  name: 'Comunidad',
                  price: '\$69 MXN / mes',
                  benefits: [
                    'Hasta diez ciclos simultáneos',
                    'Resúmenes de participación',
                  ],
                  buttonLabel: plan == AccountPlan.comunidad
                      ? 'Plan actual'
                      : 'Probar pago',
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigationBar(selectedIndex: 4),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.benefits,
    required this.buttonLabel,
    this.onPressed,
  });

  final String name;
  final String price;
  final List<String> benefits;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(benefit),
              ),
            const SizedBox(height: 8),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
