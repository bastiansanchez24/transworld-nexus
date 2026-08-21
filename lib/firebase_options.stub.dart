// Stub sin secretos para CI / clones sin FlutterFire.
// Localmente (push FCM): `flutterfire configure` → lib/firebase_options.dart
// (gitignored). En CI el workflow copia este stub o un secret opcional.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones Firebase. Con placeholders, [isConfigured] es `false` y la app
/// opera solo con inbox in-app (sin FCM).
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const _placeholder = 'REPLACE_ME';

  /// `true` solo cuando hay valores reales (no placeholder).
  static bool get isConfigured =>
      android.apiKey != _placeholder && android.appId != _placeholder;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no tienen configuración para Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soportan esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: 'tw-nexus-app',
    storageBucket: 'tw-nexus-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: 'tw-nexus-app',
    storageBucket: 'tw-nexus-app.firebasestorage.app',
    iosBundleId: 'com.transworld.nexus',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: 'tw-nexus-app',
    storageBucket: 'tw-nexus-app.firebasestorage.app',
    iosBundleId: 'com.transworld.nexus',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: 'tw-nexus-app',
    authDomain: 'tw-nexus-app.firebaseapp.com',
    storageBucket: 'tw-nexus-app.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: 'tw-nexus-app',
    authDomain: 'tw-nexus-app.firebaseapp.com',
    storageBucket: 'tw-nexus-app.firebasestorage.app',
  );
}
