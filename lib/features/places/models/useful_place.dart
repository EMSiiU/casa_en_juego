import 'package:google_maps_flutter/google_maps_flutter.dart';

enum PlaceCategory {
  recycling('Reciclaje'),
  laundry('Lavanderías'),
  cleaning('Tiendas de limpieza');

  const PlaceCategory(this.label);
  final String label;
}

class UsefulPlace {
  const UsefulPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.position,
  });
  final String id;
  final String name;
  final String address;
  final PlaceCategory category;
  final LatLng position;
}
