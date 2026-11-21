import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum FamilyPaymentResult { completed, canceled, alreadyActive }

enum AccountPlan { casa, familia, comunidad }

class FamilyPaymentFailure implements Exception {
  const FamilyPaymentFailure(this.message);
  final String message;
}

abstract interface class FamilyPaymentRepository {
  Future<AccountPlan> currentPlan();
  Future<FamilyPaymentResult> checkout(AccountPlan plan);
}

class StripeFamilyPaymentRepository implements FamilyPaymentRepository {
  StripeFamilyPaymentRepository(this.client);
  final SupabaseClient client;

  @override
  Future<AccountPlan> currentPlan() async {
    try {
      final response = await client.functions.invoke(
        'create-family-subscription',
        body: {'action': 'status'},
      );
      return AccountPlan.values.byName(response.data['plan'] as String);
    } catch (_) {
      throw const FamilyPaymentFailure(
        'No pudimos consultar tu plan. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<FamilyPaymentResult> checkout(AccountPlan plan) async {
    if (plan == AccountPlan.casa) {
      throw const FamilyPaymentFailure('Casa es gratuito y no requiere pago.');
    }
    try {
      final response = await client.functions.invoke(
        'create-family-subscription',
        body: {'action': 'checkout', 'plan': plan.name},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'active') return FamilyPaymentResult.alreadyActive;
      final key = data['publishableKey'] as String;
      final secret = data['clientSecret'] as String;
      if (!key.startsWith('pk_test_') || !secret.startsWith('pi_')) {
        throw const FamilyPaymentFailure(
          'El servicio no devolvió una configuración de pago de prueba válida.',
        );
      }
      Stripe.publishableKey = key;
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Casa en Juego · Pruebas',
          paymentIntentClientSecret: secret,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return FamilyPaymentResult.completed;
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        return FamilyPaymentResult.canceled;
      }
      throw const FamilyPaymentFailure(
        'No se pudo completar el pago. Revisa la tarjeta de prueba e intenta nuevamente.',
      );
    } on FunctionException catch (error) {
      final details = error.details;
      throw FamilyPaymentFailure(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'No pudimos preparar el pago. Revisa que la función esté desplegada y vuelve a iniciar sesión.',
      );
    } on FamilyPaymentFailure {
      rethrow;
    } catch (_) {
      throw const FamilyPaymentFailure(
        'No pudimos abrir el pago de prueba. Revisa tu conexión y vuelve a intentar.',
      );
    }
  }
}
