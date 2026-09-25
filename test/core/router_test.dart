import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/router.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/auth/ui/code_screen.dart';
import 'package:geo_ad/features/auth/ui/name_screen.dart';
import 'package:geo_ad/features/auth/ui/phone_screen.dart';
import 'package:geo_ad/features/auth/ui/start_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/fake_auth_repository.dart';
import '../features/profile/fake_profile_repository.dart';

void main() {
  final Finder phoneScreen = find.byType(PhoneScreen);
  final Finder nameScreen = find.byType(NameScreen);
  final Finder startScreen = find.byType(StartScreen);
  final Finder tabs = find.byKey(mapTabKey);

  Future<Set<Type>> pumpAndRecordScreens(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    final Set<Type> seen = <Type>{};
    void record() {
      for (final Type type in <Type>[
        StartScreen,
        PhoneScreen,
        CodeScreen,
        NameScreen,
      ]) {
        if (find.byType(type).evaluate().isNotEmpty) {
          seen.add(type);
        }
      }
      if (tabs.evaluate().isNotEmpty) {
        seen.add(SizedBox);
      }
    }

    await pumpApp(tester, repository);
    record();
    for (int i = 0; i < 10; i++) {
      await tester.pump();
      record();
    }
    return seen;
  }

  group('cold start', () {
    testWidgets('stays on the loading screen until initialSession arrives', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        emitInitialSession: false,
      );
      await pumpApp(tester, repository);
      await tester.pump(const Duration(seconds: 5));
      expect(startScreen, findsOneWidget);
      expect(find.text(AppStrings.startLoading), findsOneWidget);
      expect(phoneScreen, findsNothing);

      repository.emit(AuthChangeEvent.initialSession);
      await tester.pumpAndSettle();
      expect(phoneScreen, findsOneWidget);
    });

    testWidgets('a user with a name goes to the tabs, never the login screen', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        userId: 'user-a',
        name: 'خالد',
      )..fetchGate = Completer<void>();

      final Set<Type> seen = await pumpAndRecordScreens(tester, repository);
      expect(startScreen, findsOneWidget);
      expect(find.text(AppStrings.startLoading), findsOneWidget);

      repository.fetchGate!.complete();
      await tester.pumpAndSettle();

      expect(tabs, findsOneWidget);
      expect(locationOf(tester), Routes.map);
      expect(seen, isNot(contains(PhoneScreen)));
      expect(seen, isNot(contains(NameScreen)));
      expect(repository.fetchCalls, 1);
    });

    testWidgets('a user without a name goes to the name screen', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository(userId: 'user-new'));
      await tester.pumpAndSettle();

      expect(nameScreen, findsOneWidget);
      expect(locationOf(tester), Routes.name);
    });

    testWidgets('signed out goes to the phone screen', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      expect(phoneScreen, findsOneWidget);
      expect(locationOf(tester), Routes.login);
    });
  });

  group('signed out', () {
    for (final String location in <String>[
      Routes.map,
      Routes.myAds,
      Routes.account,
      Routes.name,
      Routes.start,
    ]) {
      testWidgets('$location redirects to the phone screen', (
        WidgetTester tester,
      ) async {
        await pumpApp(tester, FakeAuthRepository());
        await tester.pumpAndSettle();

        routerOf(tester).go(location);
        await tester.pumpAndSettle();

        expect(phoneScreen, findsOneWidget);
        expect(locationOf(tester), Routes.login);
      });
    }

    testWidgets('the code screen without a phone goes back to phone entry', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      routerOf(tester).go(Routes.loginCode);
      await tester.pumpAndSettle();

      expect(phoneScreen, findsOneWidget);
      expect(find.byType(CodeScreen), findsNothing);
    });
  });

  group('name step', () {
    for (final String location in <String>[
      Routes.map,
      Routes.myAds,
      Routes.account,
      Routes.login,
      Routes.start,
    ]) {
      testWidgets('$location stays on the name screen', (
        WidgetTester tester,
      ) async {
        await pumpApp(tester, FakeAuthRepository(userId: 'user-new'));
        await tester.pumpAndSettle();

        routerOf(tester).go(location);
        await tester.pumpAndSettle();

        expect(nameScreen, findsOneWidget);
        expect(locationOf(tester), Routes.name);
      });
    }

    testWidgets('has no back button', (WidgetTester tester) async {
      await pumpApp(tester, FakeAuthRepository(userId: 'user-new'));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsNothing);
      expect(routerOf(tester).canPop(), isFalse);
    });

    testWidgets('saving the name opens the tabs without a refetch', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        userId: 'user-new',
      );
      final FakeProfileRepository profiles = FakeProfileRepository();
      await pumpApp(tester, repository, profiles: profiles);
      await tester.pumpAndSettle();

      await submitNameAsIndividual(tester, 'سارة');
      await tester.pumpAndSettle();

      expect(tabs, findsOneWidget);
      expect(profiles.log, <String>['onboard:سارة:false:null:null']);
      expect(repository.fetchCalls, 1);
    });
  });

  group('signed in with a name', () {
    for (final String location in <String>[
      Routes.login,
      Routes.loginCode,
      Routes.name,
      Routes.start,
    ]) {
      testWidgets('$location redirects to the map', (
        WidgetTester tester,
      ) async {
        await pumpApp(tester, FakeAuthRepository(userId: 'u', name: 'خالد'));
        await tester.pumpAndSettle();
        routerOf(tester).go(Routes.account);
        await tester.pumpAndSettle();

        routerOf(tester).go(location, extra: '966511110001');
        await tester.pumpAndSettle();

        expect(locationOf(tester), Routes.map);
        expect(tabs, findsOneWidget);
      });
    }

    testWidgets('a token refresh does not refetch the name', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        userId: 'u',
        name: 'خالد',
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();

      repository.emit(AuthChangeEvent.tokenRefreshed);
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 1);
      expect(tabs, findsOneWidget);
    });
  });

  group('sign-out from anywhere', () {
    for (final String location in <String>[
      Routes.map,
      Routes.myAds,
      Routes.account,
    ]) {
      testWidgets('a lost session on $location returns to phone entry', (
        WidgetTester tester,
      ) async {
        final FakeAuthRepository repository = FakeAuthRepository(
          userId: 'u',
          name: 'خالد',
        );
        await pumpApp(tester, repository);
        await tester.pumpAndSettle();
        routerOf(tester).go(location);
        await tester.pumpAndSettle();

        repository
          ..userId = null
          ..emit(AuthChangeEvent.signedOut);
        await tester.pumpAndSettle();

        expect(phoneScreen, findsOneWidget);
        expect(locationOf(tester), Routes.login);
      });
    }

    testWidgets('a sign-out on the name screen returns to phone entry', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(userId: 'new');
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();

      repository
        ..userId = null
        ..emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();

      expect(phoneScreen, findsOneWidget);
    });

    testWidgets('a save that ends after a user switch is not applied', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(userId: 'x');
      final FakeProfileRepository profiles = FakeProfileRepository()
        ..onboardGate = Completer<void>();
      await pumpApp(tester, repository, profiles: profiles);
      await tester.pumpAndSettle();

      await submitNameAsIndividual(tester, 'سارة');
      await tester.pump();

      repository
        ..userId = null
        ..emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();
      repository
        ..userId = 'b'
        ..emit(AuthChangeEvent.signedIn);
      await tester.pumpAndSettle();
      expect(nameScreen, findsOneWidget);

      profiles.onboardGate!.complete();
      await tester.pumpAndSettle();
      expect(nameScreen, findsOneWidget);
      expect(tabs, findsNothing);
    });

    testWidgets('the next user gets their own name, not the previous one', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        userId: 'user-a',
        name: 'خالد',
      );
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();

      repository
        ..userId = null
        ..emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();
      expect(phoneScreen, findsOneWidget);

      repository
        ..name = null
        ..userId = 'user-b'
        ..emit(AuthChangeEvent.signedIn);
      await tester.pumpAndSettle();

      expect(nameScreen, findsOneWidget);
      expect(repository.fetchCalls, 2);
    });
  });

  group('profile name fails to load', () {
    testWidgets('shows the error with retry, never the name step', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(userId: 'u')
        ..fetchError = const AppException(AppErrorKind.network);

      final Set<Type> seen = await pumpAndRecordScreens(tester, repository);
      await tester.pumpAndSettle();

      expect(startScreen, findsOneWidget);
      expect(find.text(AppStrings.startErrorTitle), findsOneWidget);
      expect(find.text(AppStrings.errorNoConnection), findsOneWidget);
      expect(seen, isNot(contains(NameScreen)));

      routerOf(tester).go(Routes.name);
      await tester.pumpAndSettle();
      expect(startScreen, findsOneWidget);
      expect(nameScreen, findsNothing);
    });

    testWidgets('retry loads the name and opens the tabs', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        userId: 'u',
        name: 'خالد',
      )..fetchError = const SocketException('offline');
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.retry), findsOneWidget);

      repository.fetchError = null;
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(tabs, findsOneWidget);
      expect(repository.fetchCalls, 2);
    });

    testWidgets('is not retried automatically', (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository(userId: 'u')
        ..fetchError = const AppException(AppErrorKind.unknown);
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));

      expect(repository.fetchCalls, 1);
    });
  });

  testWidgets('full first login: phone → code → name → tabs', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0599990099');
    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    expect(find.byType(CodeScreen), findsOneWidget);

    repository.fetchGate = Completer<void>();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text(AppStrings.signInButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CodeScreen), findsOneWidget);
    expect(startScreen, findsNothing);
    expect(locationOf(tester), Routes.loginCode);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(repository.signInCalls, hasLength(1));

    repository.fetchGate!.complete();
    await tester.pumpAndSettle();
    expect(nameScreen, findsOneWidget);

    await submitNameAsIndividual(tester, 'سارة');
    await tester.pumpAndSettle();

    expect(tabs, findsOneWidget);
    expect(repository.signInCalls.single.phone, '966599990099');
  });

  testWidgets('returning user: phone → code → tabs, no name step', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository(name: 'خالد');
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0511110001');
    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text(AppStrings.signInButton));
    await tester.pumpAndSettle();

    expect(tabs, findsOneWidget);
    expect(nameScreen, findsNothing);
  });
}
