import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'map_screen.dart';
import 'sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Values come from env/dev.json via --dart-define-from-file.
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const GeoAdApp());
}

class GeoAdApp extends StatelessWidget {
  const GeoAdApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return MaterialApp(
      title: 'GeoAd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      // Rebuilds on every sign in / sign out, so this one widget decides
      // which screen you see. No router needed.
      home: StreamBuilder<AuthState>(
        stream: auth.onAuthStateChange,
        builder: (context, _) {
          if (auth.currentSession == null) {
            return const SignInScreen();
          }
          return const MapScreen();
        },
      ),
    );
  }
}
