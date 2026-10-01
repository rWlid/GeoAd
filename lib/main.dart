import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        fontFamily: 'IBMPlexSansArabic', // declared in pubspec.yaml
      ),
      // Arabic only: this alone makes every screen right-to-left and
      // translates Flutter's built-in texts (tooltips, "Cancel", ...).
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
