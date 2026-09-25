import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/router.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/core/theme.dart';
import 'package:geo_ad/features/auth/providers/auth_providers.dart';
import 'package:geo_ad/features/auth/ui/phone_screen.dart';
import 'package:geo_ad/features/profile/ui/account_screen.dart';

import '../auth/fake_auth_repository.dart';

void main() {
  final Finder logoutButton = find.widgetWithText(
    TextButton,
    AppStrings.logoutButton,
  );
  final Finder dialog = find.byType(AlertDialog);
  final Finder cancel = find.widgetWithText(TextButton, AppStrings.cancel);
  final Finder confirm = find.widgetWithText(
    TextButton,
    AppStrings.logoutConfirmAction,
  );
  final Finder retry = find.widgetWithText(FilledButton, AppStrings.retry);

  Future<FakeAuthRepository> pumpOnAccountTab(WidgetTester tester) async {
    final FakeAuthRepository repository = FakeAuthRepository(
      userId: 'user-a',
      name: 'خالد',
      phone: '966511110001',
    );
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();
    routerOf(tester).go(Routes.account);
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    return repository;
  }

  Future<void> pumpAccountScreen(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AccountScreen(),
        ),
      ),
    );
  }

  group('header', () {
    testWidgets('shows the name and the phone as 05XXXXXXXX, left to right', (
      WidgetTester tester,
    ) async {
      await pumpOnAccountTab(tester);

      expect(find.text('خالد'), findsOneWidget);
      expect(find.text('966511110001'), findsNothing);
      final Text phone = tester.widget<Text>(find.text('0511110001'));
      expect(phone.textDirection, TextDirection.ltr);
      expect(logoutButton, findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('a store shows the business name and the phone only', (
      WidgetTester tester,
    ) async {
      await pumpAccountScreen(
        tester,
        FakeAuthRepository(
          userId: 'u',
          name: 'فهد',
          isBusiness: true,
          businessName: 'متجر النخبة',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(AppStrings.tabStore),
        ),
        findsOneWidget,
      );
      expect(find.text('متجر النخبة'), findsOneWidget);
      expect(find.text('0511110001'), findsOneWidget);
      expect(find.text('فهد'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(logoutButton, findsOneWidget);
    });

    testWidgets('loading: spinner and text, logout still available', (
      WidgetTester tester,
    ) async {
      await pumpAccountScreen(
        tester,
        FakeAuthRepository(userId: 'u', name: 'خالد')
          ..fetchGate = Completer<void>(),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(AppStrings.accountLoading), findsOneWidget);
      expect(find.text('خالد'), findsNothing);
      expect(logoutButton, findsOneWidget);
    });

    for (final (AppErrorKind kind, String message) in <(AppErrorKind, String)>[
      (AppErrorKind.network, AppStrings.errorNoConnection),
      (AppErrorKind.unknown, AppStrings.errorUnknown),
    ]) {
      testWidgets('${kind.name} error: Arabic message and retry', (
        WidgetTester tester,
      ) async {
        final FakeAuthRepository repository = FakeAuthRepository(
          userId: 'u',
          name: 'خالد',
        )..fetchError = AppException(kind);
        await pumpAccountScreen(tester, repository);
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.accountErrorTitle), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.textContaining('AppException'), findsNothing);
        expect(repository.fetchCalls, 1);

        repository
          ..fetchError = null
          ..fetchGate = Completer<void>();
        await tester.tap(retry);
        await tester.pump();
        expect(find.text(AppStrings.accountLoading), findsOneWidget);
        expect(repository.fetchCalls, 2);

        repository.fetchGate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('خالد'), findsOneWidget);
        expect(find.text('0511110001'), findsOneWidget);
        expect(find.text(AppStrings.accountErrorTitle), findsNothing);
      });
    }
  });

  group('logout', () {
    testWidgets('a double tap opens one confirmation', (
      WidgetTester tester,
    ) async {
      await pumpOnAccountTab(tester);

      await tester.tap(logoutButton);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(dialog, findsOneWidget);
      expect(find.text(AppStrings.logoutConfirmTitle), findsOneWidget);
      expect(find.text(AppStrings.logoutConfirmBody), findsOneWidget);
    });

    testWidgets('Cancel closes the dialog and stays signed in', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = await pumpOnAccountTab(tester);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(repository.signOutCalls, 0);
      expect(locationOf(tester), Routes.account);
      expect(find.text('خالد'), findsOneWidget);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
    });

    testWidgets('Confirm signs out once and the router opens phone entry', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = await pumpOnAccountTab(tester);
      repository.signOutGate = Completer<void>();

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      expect(dialog, findsNothing);
      expect(locationOf(tester), Routes.account);
      expect(
        find.descendant(
          of: find.byType(TextButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(dialog, findsNothing);
      expect(repository.signOutCalls, 1);

      repository.signOutGate!.complete();
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(locationOf(tester), Routes.login);
      expect(find.byType(PhoneScreen), findsOneWidget);
    });
  });
}
