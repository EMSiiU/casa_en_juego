import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_failure.dart';
import 'auth_providers.dart';

typedef EmailAccountState = ({
  bool enteringCode,
  bool busy,
  bool finished,
  String? message,
  String? error,
});

final emailAccountProvider = NotifierProvider.autoDispose
    .family<EmailAccountController, EmailAccountState, bool>(
      EmailAccountController.new,
    );

class EmailAccountController extends Notifier<EmailAccountState> {
  EmailAccountController(this.recovery);
  final bool recovery;

  @override
  EmailAccountState build() => (
    enteringCode: false,
    busy: false,
    finished: false,
    message: null,
    error: null,
  );

  void enterCode() {
    state = (
      enteringCode: true,
      busy: false,
      finished: false,
      message: null,
      error: null,
    );
  }

  Future<void> sendCode({
    required String email,
    String? name,
    String? password,
  }) {
    final repository = ref.read(authRepositoryProvider);
    return _run(
      () => recovery
          ? repository.requestPasswordReset(email)
          : name == null
          ? repository.resendSignUpCode(email)
          : repository.signUp(name: name, email: email, password: password!),
      enteringCode: true,
      message: recovery
          ? 'Si el correo está registrado, recibirás un código para restablecer la contraseña.'
          : 'Revisa tu correo, incluida la carpeta de spam, e introduce el código.',
    );
  }

  Future<void> verify({
    required String email,
    required String code,
    String? password,
  }) {
    final repository = ref.read(authRepositoryProvider);
    return _run(
      () => recovery
          ? repository.resetPassword(
              email: email,
              code: code,
              password: password!,
            )
          : repository.confirmEmail(email: email, code: code),
      enteringCode: true,
      finished: recovery,
      message: recovery
          ? 'Contraseña actualizada. Ya puedes iniciar sesión.'
          : null,
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required bool enteringCode,
    bool finished = false,
    String? message,
  }) async {
    if (state.busy) return;
    final previousStep = state.enteringCode;
    state = (
      enteringCode: previousStep,
      busy: true,
      finished: false,
      message: null,
      error: null,
    );
    try {
      await action();
      if (!ref.mounted) return;
      state = (
        enteringCode: enteringCode,
        busy: false,
        finished: finished,
        message: message,
        error: null,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = (
        enteringCode: previousStep,
        busy: false,
        finished: false,
        message: null,
        error: AuthFailure.messageFor(error),
      );
    }
  }
}
