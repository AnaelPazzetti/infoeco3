// Este arquivo contém as configurações do Firebase para diferentes plataformas.
// Ele é gerado automaticamente pelo FlutterFire CLI.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;


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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXpmnBNIB6Ibi-d1VO30xjOZiGcPeO9vc',
    appId: '1:795380694053:web:f81b96c9f002974587d3cc',
    messagingSenderId: '795380694053',
    projectId: 'projeto-catadores',
    authDomain: 'projeto-catadores.firebaseapp.com',
    storageBucket: 'projeto-catadores.firebasestorage.app',
    measurementId: 'G-95EB0JH39G',
  );
  //

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATtYApm7Arx0FoY7RGnfVUrcyEnxZs52k',
    appId: '1:795380694053:android:e081f28051db169987d3cc',
    messagingSenderId: '795380694053',
    projectId: 'projeto-catadores',
    storageBucket: 'projeto-catadores.firebasestorage.app',
  );
//
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCS5Lw-S-PrLUG6M6GR-YszWav-K7QBh64',
    appId: '1:795380694053:ios:c5dcb29eebd2822987d3cc',
    messagingSenderId: '795380694053',
    projectId: 'projeto-catadores',
    storageBucket: 'projeto-catadores.firebasestorage.app',
    iosBundleId: 'com.example.infoeco',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCS5Lw-S-PrLUG6M6GR-YszWav-K7QBh64',
    appId: '1:795380694053:ios:c5dcb29eebd2822987d3cc',
    messagingSenderId: '795380694053',
    projectId: 'projeto-catadores',
    storageBucket: 'projeto-catadores.firebasestorage.app',
    iosBundleId: 'com.example.infoeco',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAXpmnBNIB6Ibi-d1VO30xjOZiGcPeO9vc',
    appId: '1:795380694053:web:e6e579d83b86810887d3cc',
    messagingSenderId: '795380694053',
    projectId: 'projeto-catadores',
    authDomain: 'projeto-catadores.firebaseapp.com',
    storageBucket: 'projeto-catadores.firebasestorage.app',
    measurementId: 'G-CCW626W4CS',
  );

}