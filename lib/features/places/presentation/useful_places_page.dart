import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_page_bar.dart';
import '../../auth/presentation/widgets/account_menu.dart';
import '../data/celaya_places.dart';
import '../models/useful_place.dart';
import '../providers/places_providers.dart';
import '../services/device_location.dart';

class UsefulPlacesPage extends ConsumerStatefulWidget {
  const UsefulPlacesPage({super.key});
  @override
  ConsumerState<UsefulPlacesPage> createState() => _UsefulPlacesPageState();
}

class _UsefulPlacesPageState extends ConsumerState<UsefulPlacesPage> {
  GoogleMapController? _controller;

  Future<void> _moveTo(LatLng target, {double zoom = 13}) async {
    try {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(target, zoom),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos mover el mapa. Intenta nuevamente.'),
          ),
        );
      }
    }
  }

  Future<void> _openSettings(LocationIssue issue) async {
    try {
      final opened = await ref
          .read(deviceLocationServiceProvider)
          .openSettings(issue);
      if (!opened) throw StateError('Settings unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Abre los ajustes del dispositivo y revisa el permiso de ubicación.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(nativeMapEnabledProvider);
    final category = ref.watch(placeCategoryProvider);
    final places = ref.watch(filteredPlacesProvider);
    final location = enabled ? ref.watch(deviceLocationProvider) : null;
    if (enabled) {
      ref.listen(deviceLocationProvider, (previous, next) {
        if (!next.isLoading && next.asData != null) _moveTo(next.asData!.value);
      });
    }
    final failure = location?.error;
    return Scaffold(
      appBar: AppPageBar(
        title: 'Lugares útiles',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.goNamed('profile'),
        ),
        trailing: const AccountMenu(),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Catálogo de referencia de Celaya',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final item in PlaceCategory.values)
                      ChoiceChip(
                        label: Text(item.label),
                        selected: category == item,
                        onSelected: (_) => ref
                            .read(placeCategoryProvider.notifier)
                            .select(item),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (enabled) ...[
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * .5).clamp(
                      240.0,
                      480.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: location?.asData?.value ?? celayaCenter,
                          zoom: location?.asData == null ? 11 : 13,
                        ),
                        onMapCreated: (controller) {
                          if (!mounted) return;
                          _controller = controller;
                          final position = ref
                              .read(deviceLocationProvider)
                              .asData
                              ?.value;
                          _moveTo(
                            position ?? celayaCenter,
                            zoom: position == null ? 11 : 13,
                          );
                        },
                        markers: {
                          for (final place in places)
                            Marker(
                              markerId: MarkerId(place.id),
                              position: place.position,
                              infoWindow: InfoWindow(
                                title: place.name,
                                snippet: place.address,
                              ),
                            ),
                          if (location?.asData?.value
                              case final LatLng position)
                            Marker(
                              markerId: const MarkerId('my-position'),
                              position: position,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure,
                              ),
                              infoWindow: const InfoWindow(
                                title: 'Mi ubicación',
                              ),
                            ),
                        },
                        myLocationButtonEnabled: false,
                        gestureRecognizers: {
                          Factory<OneSequenceGestureRecognizer>(
                            EagerGestureRecognizer.new,
                          ),
                        },
                        mapToolbarEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: location?.isLoading == true
                            ? null
                            : () => ref.invalidate(deviceLocationProvider),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Mi ubicación'),
                      ),
                      TextButton(
                        onPressed: () => _moveTo(celayaCenter, zoom: 11),
                        child: const Text('Ver Celaya'),
                      ),
                    ],
                  ),
                  if (location?.isLoading == true)
                    const Text('Obteniendo tu ubicación…'),
                  if (failure != null) ...[
                    Text(
                      failure is LocationFailure
                          ? failure.message
                          : 'No pudimos obtener tu ubicación.',
                    ),
                    if (failure is LocationFailure &&
                        (failure.issue == LocationIssue.disabled ||
                            failure.issue == LocationIssue.deniedForever))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _openSettings(failure.issue),
                          child: const Text('Abrir ajustes'),
                        ),
                      ),
                  ],
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'El mapa no está disponible en este dispositivo. Puedes consultar el catálogo de Celaya.',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (places.isEmpty)
                  const Text('No hay lugares en esta categoría.')
                else
                  for (final place in places)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        leading: const Icon(Icons.place_outlined),
                        onTap: enabled
                            ? () async {
                                await _moveTo(place.position);
                                if (!mounted) return;
                                try {
                                  await _controller?.showMarkerInfoWindow(
                                    MarkerId(place.id),
                                  );
                                } catch (_) {
                                  /* El nombre y la dirección también están en la lista. */
                                }
                              }
                            : null,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
