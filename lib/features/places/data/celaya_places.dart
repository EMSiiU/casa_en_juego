import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/useful_place.dart';

// Fuentes y fecha de consulta en docs/maps_setup.md. Catálogo manual, sin Places API.
const celayaCenter = LatLng(20.5289, -100.8150);
const celayaPlaces = [
  UsefulPlace(
    id: 'paper-waste',
    name: 'Paper Waste Recycling México',
    address: 'Oriente 3 núm. 205, Ciudad Industrial, Celaya, Gto.',
    category: PlaceCategory.recycling,
    position: LatLng(20.54878452, -100.79802560),
  ),
  UsefulPlace(
    id: 'lavanita',
    name: 'Lavanita',
    address: 'Francisco I. Madero 309, Zona Centro, Celaya, Gto.',
    category: PlaceCategory.laundry,
    position: LatLng(20.5226746, -100.8098133),
  ),
  UsefulPlace(
    id: 'easy-clean-nicolas-bravo',
    name: 'Easy & Clean · Nicolás Bravo',
    address: 'Nicolás Bravo 1045, Centro, Celaya, Gto.',
    category: PlaceCategory.laundry,
    position: LatLng(20.5206262, -100.8259570),
  ),
  UsefulPlace(
    id: 'aquamatic-parque-celaya',
    name: 'Aquamatic Parque Celaya',
    address: 'Av. Araucarias 719, Los Pinos II, Celaya, Gto.',
    category: PlaceCategory.laundry,
    position: LatLng(20.5457742, -100.8415830),
  ),
  UsefulPlace(
    id: 'don-pulcro-francisco-juarez',
    name: 'Don Pulcro · Francisco Juárez',
    address: 'Francisco Juárez 306, Enrique Colunga, Celaya, Gto.',
    category: PlaceCategory.cleaning,
    position: LatLng(20.5171287, -100.8255577),
  ),
  UsefulPlace(
    id: 'don-pulcro-la-capilla',
    name: 'Don Pulcro · La Capilla',
    address:
        'Av. Araucarias esq. Av. Salvador Ortega, La Capilla, Celaya, Gto.',
    category: PlaceCategory.cleaning,
    position: LatLng(20.5522807, -100.8377565),
  ),
  UsefulPlace(
    id: 'don-pulcro-los-laureles',
    name: 'Don Pulcro · Los Laureles',
    address: 'Av. Juan José Torres Landa 116, Los Laureles, Celaya, Gto.',
    category: PlaceCategory.cleaning,
    position: LatLng(20.5365428, -100.8327290),
  ),
];
