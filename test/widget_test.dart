import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts through the router with the dark theme', (
    tester,
  ) async {
    // La base visual y el enrutador se prueban sin conexión al backend.
    await tester.pumpWidget(const ProviderScope(child: CasaEnJuegoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Casa en Juego'), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).useMaterial3, isTrue);
    expect(Theme.of(context).colorScheme.primary, const Color(0xFFCBBDF8));
  });
}
