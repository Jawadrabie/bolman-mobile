import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBRiMjraiaL2UUohfTjswkPj3C3td9lsn4',
    appId: '1:771850549676:web:f58b8f04cb9a48f8c62209',
    messagingSenderId: '771850549676',
    projectId: 'safarbus-2b9b0',
    authDomain: 'safarbus-2b9b0.firebaseapp.com',
    storageBucket: 'safarbus-2b9b0.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBRiMjraiaL2UUohfTjswkPj3C3td9lsn4',
    appId: '1:771850549676:android:b8cf145b2bb5a794c62209',
    messagingSenderId: '771850549676',
    projectId: 'safarbus-2b9b0',
    storageBucket: 'safarbus-2b9b0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBRiMjraiaL2UUohfTjswkPj3C3td9lsn4',
    appId: '1:771850549676:ios:b8cf145b2bb5a794c62209',
    messagingSenderId: '771850549676',
    projectId: 'safarbus-2b9b0',
    storageBucket: 'safarbus-2b9b0.firebasestorage.app',
  );
}
