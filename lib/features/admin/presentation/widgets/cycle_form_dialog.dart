import 'package:flutter/material.dart';

typedef CycleDraft = ({String name, DateTime plannedEndDate});

class CycleFormDialog extends StatelessWidget {
  const CycleFormDialog({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final localizations = MaterialLocalizations.of(context);
    var name = '';
    DateTime? plannedEndDate;
    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nombre del ciclo'),
              validator: (value) {
                final length = (value ?? '').trim().runes.length;
                return length < 1 || length > 100
                    ? 'Escribe un nombre de 1 a 100 caracteres.'
                    : null;
              },
              onSaved: (value) => name = value!.trim(),
            ),
            const SizedBox(height: 12),
            FormField<DateTime>(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (date) {
                if (date == null) return 'Elige una fecha de fin prevista.';
                if (!date.isAfter(DateUtils.dateOnly(DateTime.now()))) {
                  return 'Elige una fecha posterior a hoy.';
                }
                return null;
              },
              onSaved: (value) => plannedEndDate = value,
              builder: (field) {
                final date = field.value;
                final now = DateTime.now();
                // Calendar days avoid a 23- or 25-hour daylight saving day.
                final days = date == null
                    ? null
                    : DateTime.utc(date.year, date.month, date.day)
                          .difference(
                            DateTime.utc(now.year, now.month, now.day),
                          )
                          .inDays;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Fecha de fin prevista'),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final firstDate = DateTime.now();
                        final tomorrow = DateTime(
                          firstDate.year,
                          firstDate.month,
                          firstDate.day + 1,
                        );
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: tomorrow,
                          lastDate: DateTime(9999, 12, 31),
                          initialDate: date != null && !date.isBefore(tomorrow)
                              ? date
                              : tomorrow,
                          initialEntryMode: DatePickerEntryMode.calendarOnly,
                          helpText: 'Fecha de fin prevista',
                        );
                        if (field.mounted && selected != null) {
                          field.didChange(selected);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        date == null
                            ? 'Elegir fecha'
                            : localizations.formatShortDate(date),
                      ),
                    ),
                    if (field.errorText case final error?)
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else if (days != null && days > 0)
                      Text(
                        days == 1
                            ? 'Duración prevista · 1 día'
                            : 'Duración prevista · $days días',
                      ),
                    const Text('El cierre se hace desde Administración.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final form = formKey.currentState!;
            if (!form.validate()) return;
            form.save();
            Navigator.of(context)
                .pop((name: name, plannedEndDate: plannedEndDate!));
          },
          child: const Text('Iniciar ciclo'),
        ),
      ],
    );
  }
}
