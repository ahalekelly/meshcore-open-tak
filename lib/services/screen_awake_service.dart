// MeshCore Open TAK - keeps the screen on while the app is open (no plugin):
// FLAG_KEEP_SCREEN_ON on Android (MainActivity.kt) and the idle timer on iOS
// (AppDelegate.swift). The system's own sleep and lock come back as soon as
// the app is in the background or the setting is turned off. Elsewhere it
// quietly does nothing.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenAwakeService {
  ScreenAwakeService._();
  static final ScreenAwakeService instance = ScreenAwakeService._();

  static const _channel = MethodChannel('meshcore_open/screen_awake');

  /// Whether this platform can keep the screen on.
  static bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _on = false;

  /// Keeps the screen on, or lets it sleep again. Only calls the platform
  /// when the state changes.
  Future<void> apply(bool on) async {
    if (!available || on == _on) return;
    _on = on;
    try {
      await _channel.invokeMethod<void>('set', on);
    } on MissingPluginException {
      // An older build or a test: nothing to do.
    } on PlatformException {
      // The window isn't there yet; the next change tries again.
      _on = !on;
    }
  }
}
