import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/admin_dashboard.dart';
import '../../providers/admin_providers.dart';
import 'admin_scaffold.dart';

class CloseSeasonSheet extends ConsumerWidget {
  const CloseSeasonSheet({super.key, required this.summary});
  final SeasonSummary summary;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(adminActionProvider);
    return PopScope(
      canPop: !action.isBusy,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryText,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: Color(0xFFF3A69B),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¿Finalizar ${summary.season.name}?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'El ranking y los ${summary.approvedPoints} puntos aprobados se conservarán. Ya no se podrán registrar ni revisar tareas en este ciclo.',
                style: const TextStyle(color: Color(0xFFB8B9C9), height: 1.5),
              ),
              const SizedBox(height: 16),
              AdminInfo(
                summary.pendingCount == 0
                    ? 'No hay solicitudes pendientes en la última actualización.'
                    : 'Hay ${summary.pendingCount == 1 ? '1 solicitud pendiente' : '${summary.pendingCount} solicitudes pendientes'}. Recomendamos resolverlas antes de cerrar.',
                warning: summary.pendingCount > 0,
              ),
              const SizedBox(height: 16),
              const Text(
                'El cierre no adjudica puntos ni traslada solicitudes al siguiente ciclo. Las pendientes quedarán sin resolver.',
                style: TextStyle(
                  color: Color(0xFFB8B9C9),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (action.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  action.errorMessage!,
                  style: const TextStyle(color: Color(0xFFF3A69B)),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: action.isBusy || action.errorMessage != null
                    ? null
                    : () async {
                        final closed = await ref
                            .read(adminActionProvider.notifier)
                            .closeSeason(summary.season.id);
                        if (context.mounted && closed) {
                          Navigator.of(context).pop(true);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF3A69B),
                  foregroundColor: AppTheme.background,
                ),
                child: Text(action.isBusy ? 'Finalizando…' : 'Finalizar ciclo'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: action.isBusy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  action.errorMessage == null ? 'Cancelar' : 'Volver al panel',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
