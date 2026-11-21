/// Detecta dos impulsos separados por un retorno por debajo del umbral.
class ShakeDetector {
  Duration? _firstImpulse;
  Duration? _lastShake;
  bool _aboveThreshold = false;

  bool add(double x, double y, double z, Duration elapsed) {
    final above = x * x + y * y + z * z >= 12 * 12;
    if (!above) {
      _aboveThreshold = false;
      return false;
    }
    if (_aboveThreshold) return false;
    _aboveThreshold = true;
    if (_lastShake != null &&
        elapsed - _lastShake! < const Duration(seconds: 2)) {
      return false;
    }
    final interval = _firstImpulse == null ? null : elapsed - _firstImpulse!;
    if (interval == null || interval > const Duration(milliseconds: 600)) {
      _firstImpulse = elapsed;
      return false;
    }
    if (interval < const Duration(milliseconds: 80)) return false;
    _firstImpulse = null;
    _lastShake = elapsed;
    return true;
  }
}
