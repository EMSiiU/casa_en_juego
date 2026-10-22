import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/auth_failure.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (mounted && !ref.read(authControllerProvider).hasError) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.home_outlined, color: AppTheme.primary),
                            SizedBox(width: 10),
                            Text('Casa en Juego'),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const _HouseIllustration(),
                        const SizedBox(height: 32),
                        Text(
                          'Una casa limpia.\nUn equipo que suma.',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.12,
                              ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Reparte el esfuerzo, registra tus tareas y sube en el ranking familiar.',
                          style: TextStyle(
                            color: Color(0xFFB8B9C9),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text('Correo electrónico'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          enabled: !action.isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'ana@familia.es',
                            suffixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Escribe tu correo electrónico.';
                            }
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
                              return 'Escribe un correo electrónico válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text('Contraseña'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !action.isLoading,
                          obscureText: _obscurePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            helperText: 'Toca el ojo para mostrar u ocultar.',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: action.isLoading
                                  ? null
                                  : () => setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Escribe tu contraseña.'
                              : null,
                        ),
                        if (action.hasError) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              AuthFailure.messageFor(action.error!),
                              style: const TextStyle(color: Color(0xFFF3A69B)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: action.isLoading ? null : _submit,
                          icon: action.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward, size: 20),
                          label: Text(
                            action.isLoading
                                ? 'Iniciando sesión…'
                                : 'Iniciar sesión',
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          '¿Necesitas acceso?\nHabla con el administrador',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8B9C9),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 13,
                              color: AppTheme.secondaryText,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Solo para tu familia · Sin registro público',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 11,
                                ),
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
          ),
        ),
      ),
    );
  }
}

class _HouseIllustration extends StatelessWidget {
  const _HouseIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 168,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF39334F),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ),
            const Icon(Icons.home_outlined, size: 72, color: AppTheme.primary),
            const Positioned(
              right: 0,
              top: 16,
              child: _IllustrationBadge(
                icon: Icons.auto_awesome_outlined,
                color: Color(0xFFF2C978),
              ),
            ),
            const Positioned(
              left: 0,
              bottom: 8,
              child: _IllustrationBadge(
                icon: Icons.check,
                color: Color(0xFF91D5C6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  const _IllustrationBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 22, color: color),
  );
}
