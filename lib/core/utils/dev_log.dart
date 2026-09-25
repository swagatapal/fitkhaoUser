import 'package:flutter/foundation.dart';

/// Debug-only logging for verbose diagnostics.
///
/// `debugPrint` is NOT stripped from release builds, and the argument is
/// evaluated before the call — so `debugPrint('resp: $json')` builds the whole
/// decoded response into a string on the UI thread in production. Passing a
/// closure here means the message is never constructed unless [kDebugMode].
///
/// Use for verbose payload dumps only. Keep real diagnostics (errors, state
/// transitions) on `debugPrint` so they still surface in release logs.
void devLog(String Function() message) {
  if (kDebugMode) {
    debugPrint(message());
  }
}
