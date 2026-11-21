import 'package:flutter/material.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_page_bar.dart';
import '../../auth/presentation/widgets/account_menu.dart';

class PlansPage extends StatelessWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppPageBar(title: 'Planes', trailing: AccountMenu(),),
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
              const _PlanCard(
                name: 'Casa',
                price: 'Gratis',
                benefits: [
                  'Un ciclo activo',
                  'Tareas personalizadas',
                  'Historial de actividad',
                ],
                buttonLabel: 'Plan actual',
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                name: 'Familia',
                price: '\$39 MXN / mes',
                benefits: [
                  'Hasta tres ciclos simultáneos',
                  'Para casa, escuela y actividades familiares',
                ],
                buttonLabel: 'Probar pago',
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                name: 'Comunidad',
                price: '\$69 MXN / mes',
                benefits: [
                  'Hasta diez ciclos simultáneos',
                  'Resúmenes de participación',
                ],
                buttonLabel: 'Probar pago',
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: const AppNavigationBar(selectedIndex: 4),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.benefits,
    required this.buttonLabel,
  });

  final String name;
  final String price;
  final List<String> benefits;
  final String buttonLabel;

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
            FilledButton(onPressed: null, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
