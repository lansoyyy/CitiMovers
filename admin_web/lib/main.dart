import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final auth = AdminAuthService();
  await auth.init();

  runApp(CitiMoversAdminApp(auth: auth));
}

class CitiMoversAdminApp extends StatelessWidget {
  final AdminAuthService auth;
  const CitiMoversAdminApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(auth);
    return MaterialApp.router(
      title: 'CitiMovers Admin',
      theme: AdminTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
