import 'dart:async';

import 'package:casa_en_juego/features/auth/models/auth_failure.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/auth/repositories/oauth_sign_in.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show FakeAuthRepository, testUser;

void main() {
  test('OAuth redirects to the native callback or the current web origin', () {
    final local = Uri.parse('http://localhost:8080/?code=old#/login');
    expect(
      oauthRedirectTo(isWeb: true, appUri: local),
      'http://localhost:8080/',
    );
    expect(
      oauthRedirectTo(
        isWeb: true,
        appUri: Uri.parse('https://casaenjuego.web.app/#/login'),
      ),
      'https://casaenjuego.web.app/',
    );
    expect(
      oauthRedirectTo(isWeb: false, appUri: local),
      'casaenjuego://auth/callback',
    );
  });

  testWidgets(
    'Google and GitHub wait for a Supabase session before opening tasks',
    (tester) async {
      final auth = FakeAuthRepository();
      final providers = <OAuthProvider>[];
      final googleLaunch = Completer<void>();
      addTearDown(auth.events.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            reviewsRepositoryProvider.overrideWithValue(
              FakeReviewsRepository(),
            ),
            tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
            oauthSignInProvider.overrideWithValue((provider) async {
              providers.add(provider);
              if (provider == OAuthProvider.google) await googleLaunch.future;
            }),
          ],
          child: const CasaEnJuegoApp(),
        ),
      );
      await tester.pumpAndSettle();
      final google = find.widgetWithText(
        OutlinedButton,
        'Continuar con Google',
      );
      final github = find.widgetWithText(
        OutlinedButton,
        'Continuar con GitHub',
      );
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pump();
      expect(providers, [OAuthProvider.google]);
      expect(tester.widget<OutlinedButton>(github).onPressed, isNull);

      googleLaunch.complete();
      await tester.pumpAndSettle();
      expect(google, findsOneWidget);
      await tester.ensureVisible(github);
      await tester.tap(github);
      await tester.pumpAndSettle();
      expect(providers, [OAuthProvider.google, OAuthProvider.github]);
      expect(github, findsOneWidget);

      auth.user = testUser;
      auth.events.add(testUser);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(github, findsNothing);
    },
  );

  testWidgets('Failure to open the browser leaves email login available', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          oauthSignInProvider.overrideWithValue((_) async {
            throw const AuthFailure('No pudimos abrir el navegador.');
          }),
        ],
        child: const CasaEnJuegoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final google = find.widgetWithText(OutlinedButton, 'Continuar con Google');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(find.text('No pudimos abrir el navegador.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
  });
}
