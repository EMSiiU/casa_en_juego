import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationIssue { disabled, denied, deniedForever, unavailable }

class LocationFailure implements Exception {
  const LocationFailure(this.issue, this.message);
  final LocationIssue issue;
  final String message;
}

class DeviceLocation {
  Future<LatLng> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(
          LocationIssue.disabled,
          'La ubicación está desactivada. Puedes consultar los lugares de Celaya.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(
          LocationIssue.deniedForever,
          'Permite la ubicación desde los ajustes de la app para ver tu posición.',
        );
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const LocationFailure(
          LocationIssue.denied,
          'No se concedió el permiso. El mapa seguirá mostrando Celaya.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(
        LocationIssue.unavailable,
        'La ubicación tardó demasiado. Puedes volver a intentarlo.',
      );
    } catch (_) {
      throw const LocationFailure(
        LocationIssue.unavailable,
        'No pudimos obtener tu ubicación. Puedes consultar los lugares de Celaya.',
      );
    }
  }

  Future<bool> openSettings(LocationIssue issue) =>
      issue == LocationIssue.disabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
