import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/email_account_provider.dart';

class EmailAccountPage extends ConsumerStatefulWidget {
  const EmailAccountPage({
    super.key,
    required this.recovery,
    this.initialEmail,
  });

  final bool recovery;
  final String? initialEmail;

  @override
  ConsumerState<EmailAccountPage> createState() => _EmailAccountPageState();
}

class _EmailAccountPageState extends ConsumerState<EmailAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailAccountProvider(widget.recovery));
    final controller = ref.read(emailAccountProvider(widget.recovery).notifier);
    final registering = !widget.recovery && !state.enteringCode;
    final choosingPassword =
        registering || (widget.recovery && state.enteringCode);
    final heading = widget.recovery
        ? 'Recuperar contraseña'
        : state.enteringCode
        ? 'Confirma tu correo'
        : 'Crear cuenta';
    return Scaffold(
      appBar: AppBar(
        title: Text(heading),
        leading: IconButton(
          tooltip: 'Volver al inicio de sesión',
          icon: const Icon(Icons.arrow_back),
          onPressed: state.busy ? null : () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!state.finished) ...[
                      if (registering) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !state.busy,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                          validator: (value) => value!.trim().isEmpty
                              ? 'Escribe tu nombre.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        key: _emailKey,
                        controller: _email,
                        enabled: !state.busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        validator: (value) =>
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value!.trim())
                            ? null
                            : 'Escribe un correo electrónico válido.',
                      ),
                      if (state.enteringCode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _code,
                          enabled: !state.busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: const InputDecoration(
                            labelText: 'Código del correo',
                          ),
                          validator: (value) => (value?.length ?? 0) < 6
                              ? 'Introduce el código que te enviamos.'
                              : null,
                        ),
                      ],
                      if (choosingPassword) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !state.busy,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: widget.recovery
                                ? 'Nueva contraseña'
                                : 'Contraseña',
                            helperText: 'Usa al menos ocho caracteres.',
                          ),
                          validator: (value) => (value?.length ?? 0) < 8
                              ? 'Escribe una contraseña de al menos ocho caracteres.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          enabled: !state.busy,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Repite la contraseña',
                          ),
                          validator: (value) => value != _password.text
                              ? 'Las contraseñas deben coincidir.'
                              : null,
                        ),
                      ],
                    ],
                    if (state.message case final message?) ...[
                      const SizedBox(height: 16),
                      Semantics(liveRegion: true, child: Text(message)),
                    ],
                    if (state.error case final error?) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (state.finished)
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Ir a iniciar sesión'),
                      )
                    else ...[
                      FilledButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                if (!_formKey.currentState!.validate()) return;
                                FocusScope.of(context).unfocus();
                                final email = _email.text.trim();
                                if (state.enteringCode) {
                                  controller.verify(
                                    email: email,
                                    code: _code.text,
                                    password: widget.recovery
                                        ? _password.text
                                        : null,
                                  );
                                } else {
                                  controller.sendCode(
                                    email: email,
                                    name: registering
                                        ? _name.text.trim()
                                        : null,
                                    password: registering
                                        ? _password.text
                                        : null,
                                  );
                                }
                              },
                        child: Text(
                          state.busy
                              ? 'Un momento…'
                              : registering
                              ? 'Enviar código de confirmación'
                              : !state.enteringCode
                              ? 'Enviar código de recuperación'
                              : widget.recovery
                              ? 'Guardar nueva contraseña'
                              : 'Confirmar correo',
                        ),
                      ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                if (!state.enteringCode) {
                                  _password.clear();
                                  controller.enterCode();
                                  return;
                                }
                                if (!_emailKey.currentState!.validate()) return;
                                _code.clear();
                                controller.sendCode(email: _email.text.trim());
                              },
                        child: Text(
                          state.enteringCode
                              ? 'Reenviar código'
                              : 'Ya tengo un código',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
