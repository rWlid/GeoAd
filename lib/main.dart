import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'complete_profile_screen.dart';
import 'home_screen.dart';
import 'sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
          final session = auth.currentSession;
          if (session == null) {
            return const SignInScreen();
          }
          return _ProfileGate(key: ValueKey(session.user.id));
        },
      ),
    );
  }
}

// Decides between the onboarding form and the home screen. Keyed by user id,
// so signing in with another account re-checks the new profile.
class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<bool> _needsProfile = _check();
  bool _completed = false;

  Future<bool> _check() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) return true;

    final row = await db
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();
    final Object? name = row?['name'];
    return name is! String || name.trim().isEmpty;
  }

  void _retry() {
    setState(() => _needsProfile = _check());
  }

  void _onSaved() {
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return const HomeScreen();
    }

    return FutureBuilder<bool>(
      future: _needsProfile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('حدث خطأ أثناء تحميل بيانات حسابك'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!) {
          return CompleteProfileScreen(onSaved: _onSaved);
        }
        return const HomeScreen();
      },
    );
  }
}
