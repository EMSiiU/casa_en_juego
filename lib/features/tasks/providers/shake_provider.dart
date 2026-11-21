import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/shake_detector.dart';

final userAccelerationProvider = Provider<Stream<UserAccelerometerEvent>>(
  (ref) => userAccelerometerEventStream(
    samplingPeriod: const Duration(milliseconds: 50),
  ),
);

final shakeEventsProvider = StreamProvider.autoDispose<int>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError('Agitar está disponible en Android.');
  }
  final events = StreamController<int>();
  StreamSubscription<UserAccelerometerEvent>? subscription;
  var sequence = 0;
  var failed = false;

  void stop() {
    subscription?.cancel();
    subscription = null;
  }

  void fail(Object error, StackTrace stack) {
    failed = true;
    stop();
    if (!events.isClosed) events.addError(error, stack);
  }

  void start() {
    if (subscription != null || failed || events.isClosed) return;
    final detector = ShakeDetector();
    final clock = Stopwatch()..start();
    try {
      subscription = ref
          .read(userAccelerationProvider)
          .listen(
            (event) {
              if (detector.add(event.x, event.y, event.z, clock.elapsed)) {
                events.add(++sequence);
              }
            },
            onError: fail,
            cancelOnError: true,
          );
    } catch (error, stack) {
      fail(error, stack);
    }
  }

  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      if (state == AppLifecycleState.resumed) {
        start();
      } else {
        stop();
      }
    },
  );
  events.onListen = () {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) start();
  };
  ref.onDispose(() {
    lifecycle.dispose();
    stop();
    events.close();
  });
  return events.stream;
}, retry: (count, error) => null);
