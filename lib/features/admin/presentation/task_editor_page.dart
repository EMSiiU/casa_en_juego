import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/presentation/widgets/task_icon.dart';
import '../models/admin_failure.dart';
import '../models/task_draft.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_scaffold.dart';

class TaskEditorPage extends ConsumerWidget {
  const TaskEditorPage({super.key, this.taskId});
  final String? taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(adminActionProvider).isBusy;
    return AdminScaffold(
      title: taskId == null ? 'Nueva tarea' : 'Editar tarea',
      subtitle: 'ADMINISTRADOR · CATÁLOGO',
      isBusy: busy,
      child: taskId == null
          ? const _TaskForm()
          : ref
                .watch(adminTaskProvider(taskId!))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => AdminLoadError(
                    message: AdminFailure.messageFor(error),
                    onRetry: () => ref.invalidate(adminTaskProvider(taskId!)),
                  ),
                  data: (task) =>
                      _TaskForm(key: ValueKey(task.id), initialTask: task),
                ),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({super.key, this.initialTask});
  final HouseholdTask? initialTask;
  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _pointsController;
  late String _iconName;
  late bool _isActive;
  late bool _isDailyLimited;
  String? _validationError;
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialTask?.name ?? '',
    );
    _pointsController = TextEditingController(
      text: widget.initialTask?.points.toString() ?? '',
    );
    _iconName = widget.initialTask?.iconName ?? 'broom';
    _isActive = widget.initialTask?.isActive ?? true;
    _isDailyLimited = widget.initialTask?.isDailyLimited ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    TaskDraft draft;
    try {
      draft = TaskDraft(
        name: _nameController.text,
        points: int.parse(_pointsController.text),
        iconName: _iconName,
        isActive: _isActive,
        isDailyLimited: _isDailyLimited,
      );
    } on AdminFailure catch (error) {
      setState(() => _validationError = error.message);
      return;
    }
    setState(() => _validationError = null);
    FocusScope.of(context).unfocus();
    final saved = await ref
        .read(adminActionProvider.notifier)
        .saveTask(id: widget.initialTask?.id, draft: draft);
    if (mounted && saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          persist: false,
          content: Text('Tarea guardada.'),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/admin/tasks');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(adminActionProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFF39334F),
                child: ListTile(
                  leading: TaskIcon(iconName: _iconName),
                  title: Text(
                    _nameController.text.trim().isEmpty
                        ? 'Tu nueva tarea'
                        : _nameController.text,
                  ),
                  subtitle: Text(
                    '${_pointsController.text.isEmpty ? '0' : _pointsController.text} puntos · ${_isActive ? 'Activa' : 'Inactiva'}',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                enabled: !action.isBusy,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nombre de la tarea',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el nombre de la tarea.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pointsController,
                enabled: !action.isBusy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Puntos',
                  helperText: 'Valor que suma cada solicitud aprobada.',
                ),
                validator: (value) {
                  final points = int.tryParse(value ?? '');
                  return points == null || points < 1 || points > 2147483647
                      ? 'Escribe un entero entre 1 y 2147483647.'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              const Text('Ícono de la tarea'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in TaskIconOption.values)
                    Tooltip(
                      message: option.label,
                      child: Semantics(
                        selected: _iconName == option.name,
                        button: true,
                        label: option.label,
                        child: InkWell(
                          onTap: action.isBusy
                              ? null
                              : () => setState(() => _iconName = option.name),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _iconName == option.name
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TaskIcon(iconName: option.name, size: 40),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Una vez al día'),
                subtitle: Text(
                  _isDailyLimited
                      ? 'Se renueva a medianoche de Ciudad de México. Si se rechaza, se puede reenviar.'
                      : 'Se puede repetir varias veces al día.',
                ),
                value: _isDailyLimited,
                onChanged: action.isBusy
                    ? null
                    : (value) => setState(() => _isDailyLimited = value),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarea activa'),
                value: _isActive,
                subtitle: Text(
                  _isActive
                      ? 'Disponible para registrar'
                      : 'Oculta del catálogo familiar',
                ),
                onChanged: action.isBusy
                    ? null
                    : (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              const AdminInfo(
                'Si la desactivas, dejará de aparecer para registrar tareas. El historial se conserva. Cambiar puntos solo afecta a nuevas solicitudes.',
              ),
              if (_validationError != null || action.errorMessage != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _validationError ?? action.errorMessage!,
                    style: const TextStyle(color: Color(0xFFF3A69B)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: action.isBusy ? null : _save,
                child: Text(action.isBusy ? 'Guardando…' : 'Guardar cambios'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: action.isBusy
                    ? null
                    : () => context.canPop()
                          ? context.pop()
                          : context.go('/admin/tasks'),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
