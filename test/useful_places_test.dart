import 'dart:async';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/places/data/celaya_places.dart';
import 'package:casa_en_juego/features/places/models/useful_place.dart';
import 'package:casa_en_juego/features/places/presentation/useful_places_page.dart';
import 'package:casa_en_juego/features/places/providers/places_providers.dart';
import 'package:casa_en_juego/features/places/services/device_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'profile_test.dart' show startProfile;
import 'support/fake_profile_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

class _LocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0;
  int reads = 0;
  Object? error;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    if (error != null) throw error!;
    return Position(
      latitude: 20.53,
      longitude: -100.81,
      timestamp: DateTime(2026),
      accuracy: 30,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late _LocationPlatform platform;
  late GeolocatorPlatform previous;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = _LocationPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = previous);

  test('Requests permission and returns an actual device fix', () async {
    final result = await DeviceLocation().currentPosition();
    expect(result.latitude, 20.53);
    expect(result.longitude, -100.81);
    expect(platform.requests, 1);
    expect(platform.reads, 1);
  });
  test('Existing permission avoids another prompt', () async {
    platform.permission = LocationPermission.whileInUse;
    await DeviceLocation().currentPosition();
    expect(platform.requests, 0);
    expect(platform.reads, 1);
  });
  test('Disabled service does not prompt or read location', () async {
    platform.enabled = false;
    await expectLater(
      DeviceLocation().currentPosition(),
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.issue,
          'issue',
          LocationIssue.disabled,
        ),
      ),
    );
    expect(platform.requests, 0);
    expect(platform.reads, 0);
  });
  for (final denied in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('Denied permission $denied does not read location', () async {
      platform.permission = denied;
      platform.requested = denied;
      await expectLater(
        DeviceLocation().currentPosition(),
        throwsA(
          isA<LocationFailure>().having(
            (e) => e.issue,
            'issue',
            denied == LocationPermission.deniedForever
                ? LocationIssue.deniedForever
                : LocationIssue.denied,
          ),
        ),
      );
      expect(
        platform.requests,
        denied == LocationPermission.deniedForever ? 0 : 1,
      );
      expect(platform.reads, 0);
    });
  }
  test('Timeout produces a recoverable location error', () async {
    platform.error = TimeoutException('No fix');
    await expectLater(
      DeviceLocation().currentPosition(),
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.message,
          'message',
          contains('tardó demasiado'),
        ),
      ),
    );
  });
  test('Platform errors are safe and allow the catalog fallback', () async {
    platform.error = StateError('internal-details');
    await expectLater(
      DeviceLocation().currentPosition(),
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('internal-details')),
        ),
      ),
    );
  });

  testWidgets('Catalog filters work without native map or location requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nativeMapEnabledProvider.overrideWithValue(false)],
        child: const MaterialApp(home: UsefulPlacesPage()),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 1100.0]) {
      tester.view.physicalSize = Size(width, 720);
      await tester.pumpAndSettle();
      for (final category in PlaceCategory.values) {
        await tester.scrollUntilVisible(
          find.widgetWithText(ChoiceChip, category.label),
          -150,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(category.label));
        await tester.pumpAndSettle();
        for (final place in celayaPlaces) {
          if (place.category == category) {
            await tester.scrollUntilVisible(find.text(place.name), 150);
            await tester.pumpAndSettle();
          }
          expect(
            find.text(place.name),
            place.category == category ? findsOneWidget : findsNothing,
          );
          if (place.category == category) {
            expect(find.text(place.address), findsOneWidget);
          }
        }
      }
      expect(tester.takeException(), isNull);
    }
    expect(platform.requests, 0);
    expect(platform.reads, 0);
  });

  testWidgets('Empty catalog explains missing results', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeMapEnabledProvider.overrideWithValue(false),
          placesCatalogProvider.overrideWithValue([]),
        ],
        child: const MaterialApp(home: UsefulPlacesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay lugares en esta categoría.'), findsOneWidget);
  });

  testWidgets(
    'Account without a cycle can open places from Profile and go back',
    (tester) async {
      const user = AppUser(
        id: 'member-id',
        name: 'Ana',
        email: 'ana@example.com',
        role: UserRole.sibling,
        notificationsEnabled: false,
        isHouseholdMember: false,
      );
      final auth = FakeAuthRepository()..user = user;
      final container = await startProfile(
        tester,
        FakeProfileRepository()..user = user,
        auth: auth,
      );
      await tester.scrollUntilVisible(
        find.text('Lugares útiles'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lugares útiles'));
      await tester.pumpAndSettle();
      expect(find.byType(UsefulPlacesPage), findsOneWidget);
      container.read(appRouterProvider).go('/profile/lugares');
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/profile/lugares',
      );
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/profile',
      );
    },
  );
}
