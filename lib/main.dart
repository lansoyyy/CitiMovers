import 'package:citimovers/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'services/firestore_schema_seeder.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase with duplicate app error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Ignore duplicate app error - Firebase is already initialized
    if (e.toString().contains('[core/duplicate-app]')) {
      // Firebase is already initialized, continue
    } else {
      rethrow;
    }
  }

  const seedSchema = bool.fromEnvironment('FIRESTORE_SEED_SCHEMA');
  if (seedSchema) {
    await FirestoreSchemaSeeder.seed();
  }

  await GetStorage.init();

  runApp(const CitiMoversApp());
}

class CitiMoversApp extends StatelessWidget {
  const CitiMoversApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
