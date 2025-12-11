import 'package:citimovers/firebase_options.dart';
import 'package:citimovers/rider/screens/auth/rider_splash_screen.dart';
import 'package:citimovers/rider/screens/rider_home_screen.dart';
import 'package:citimovers/screens/home_screen.dart';
import 'package:citimovers/uber_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(
    name: 'citimovers-346f2',
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      home: const HomeScreen(),
    );
  }
}
