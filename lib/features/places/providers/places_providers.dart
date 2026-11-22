import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/celaya_places.dart';
import '../models/useful_place.dart';
import '../services/device_location.dart';

final nativeMapEnabledProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY').isNotEmpty,
);
final placesCatalogProvider = Provider<List<UsefulPlace>>(
  (ref) => celayaPlaces,
);
final placeCategoryProvider =
    NotifierProvider.autoDispose<PlaceCategoryController, PlaceCategory>(
      PlaceCategoryController.new,
    );

class PlaceCategoryController extends Notifier<PlaceCategory> {
  @override
  PlaceCategory build() => PlaceCategory.recycling;
  void select(PlaceCategory category) => state = category;
}

final filteredPlacesProvider = Provider.autoDispose<List<UsefulPlace>>((ref) {
  final category = ref.watch(placeCategoryProvider);
  return ref
      .watch(placesCatalogProvider)
      .where((place) => place.category == category)
      .toList();
});
final deviceLocationServiceProvider = Provider<DeviceLocation>(
  (ref) => DeviceLocation(),
);
final deviceLocationProvider = FutureProvider.autoDispose<LatLng>(
  (ref) => ref.watch(deviceLocationServiceProvider).currentPosition(),
  retry: (count, error) => null,
);
