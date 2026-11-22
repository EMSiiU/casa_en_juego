import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';

const _steps = [
  (
    icon: Icons.home_outlined,
    title: 'Bienvenido a Casa en Juego',
    text: 'Organiza las tareas de casa y reconoce la participación de todos. Cada ciclo tiene sus propias personas, tareas y puntos.',
  ),
  (
    icon: Icons.group_add_outlined,
    title: 'Crea un ciclo o únete',
    text: 'Desde Perfil, usa Unirme con código o entra a Administración para crear un ciclo con nombre y fecha prevista. Cada cuenta participa en un ciclo activo a la vez.',
  ),
  (
    icon: Icons.checklist_outlined,
    title: 'Registra y revisa tareas',
    text: 'Cuando termines una tarea, selecciónala en Tareas y envíala a revisión. Otro miembro debe aprobarla para sumar puntos. Tú puedes revisar las tareas de los demás.',
  ),
  (
    icon: Icons.vibration,
    title: 'Agita para recibir una sugerencia',
    text: 'En Android, agita el celular en Tareas para recibir una sugerencia disponible. Agitar no registra trabajo: realiza la tarea y después envíala a revisión desde la lista.',
  ),
  (
    icon: Icons.emoji_events_outlined,
    title: 'Consulta tu progreso',
    text: 'Ranking muestra los puntos aprobados del ciclo. Desde Perfil → Mi actividad puedes consultar tus solicitudes pendientes, aprobadas y rechazadas.',
  ),
  (
    icon: Icons.flag_outlined,
    title: 'Finaliza un ciclo',
    text: 'Si eres administrador, entra en Perfil → Cuidar del equipo y elige Finalizar ciclo. Los resultados quedan en Historial de ciclos. El siguiente ciclo empieza de cero, con catálogo base y un código nuevo para invitar a sus miembros.',
  ),
];

final _stepProvider = NotifierProvider.autoDispose<_StepController, int>(
  _StepController.new,
);

class _StepController extends Notifier<int> {
  @override
  int build() => 0;
  void next() {
    if (state < _steps.length - 1) state++;
  }

  void previous() {
    if (state > 0) state--;
  }
}

Future<void> showOnboardingDialog(
  BuildContext context, {
  required String accountId,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => ProviderScope(
    overrides: [_stepProvider.overrideWith(_StepController.new)],
    child: _OnboardingDialog(accountId: accountId),
  ),
);

class _OnboardingDialog extends ConsumerWidget {
  const _OnboardingDialog({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_stepProvider);
    final step = _steps[index];
    final last = index == _steps.length - 1;
    ref.listen(currentUserProvider, (previous, next) {
      if (!next.isLoading &&
          !next.hasError &&
          next.asData?.value?.id != accountId &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
    return AlertDialog(
      scrollable: true,
      constraints: const BoxConstraints(maxWidth: 500),
      icon: Icon(
        step.icon,
        size: 40,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Paso ${index + 1} de ${_steps.length}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(step.title),
        ],
      ),
      content: Text(step.text),
      actions: [
        if (!last)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Omitir'),
          ),
        if (index > 0 && !last)
          TextButton(
            onPressed: ref.read(_stepProvider.notifier).previous,
            child: const Text('Atrás'),
          ),
        FilledButton(
          onPressed: last
              ? () => Navigator.of(context).pop()
              : ref.read(_stepProvider.notifier).next,
          child: Text(last ? 'Cerrar' : 'Siguiente'),
        ),
      ],
    );
  }
}
