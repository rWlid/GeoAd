import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/strings_ar.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isComplete) {
    runApp(
      const _StartupErrorApp(
        title: AppStrings.missingEnvTitle,
        body: AppStrings.missingEnvBody,
        showRunCommand: true,
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // anonKey is deprecated in the sdk; legacy anon keys still work here
      publishableKey: Env.supabaseAnonKey,
    );
  } catch (error, stackTrace) {
    debugPrint('Supabase.initialize failed: $error\n$stackTrace');
    runApp(
      const _StartupErrorApp(
        title: AppStrings.startupFailedTitle,
        body: AppStrings.startupFailedBody,
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: GeoAdApp()));
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({
    required this.title,
    required this.body,
    this.showRunCommand = false,
  });

  final String title;
  final String body;
  final bool showRunCommand;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        // Builder so Theme.of sees the theme above, not the default one
        child: Builder(
          builder: (BuildContext context) {
            final TextTheme textTheme = Theme.of(context).textTheme;

            return Scaffold(
              body: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        title,
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(body, textAlign: TextAlign.center),
                      if (showRunCommand) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppStrings.runWithEnvCommand,
                          textDirection: TextDirection.ltr,
                          style: textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
