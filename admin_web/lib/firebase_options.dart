// Firebase configuration for CitiMovers Admin Web Panel.
// Uses the same Firebase project as the mobile app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_BC1x1V0RJ1qbyIxURnjMblME3r2n278',
    authDomain: 'citimovers-346f2.firebaseapp.com',
    databaseURL: 'https://citimovers-346f2-default-rtdb.firebaseio.com',
    projectId: 'citimovers-346f2',
    storageBucket: 'citimovers-346f2.firebasestorage.app',
    messagingSenderId: '212204568146',
    appId: '1:212204568146:web:2e9d8c15d433ba9976e98b',
  );
}
