import 'package:flutter/foundation.dart';

class AppError {
  static void log(String context, Object error, [StackTrace? stack]) {
    debugPrint('[$context] ERROR: $error');
    if (stack != null) debugPrint(stack.toString());
    // In production: plug in Sentry, Firebase Crashlytics, etc.
  }
}
