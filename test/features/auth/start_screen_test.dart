import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/auth/ui/phone_screen.dart';
import 'package:geo_ad/features/auth/ui/start_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth_repository.dart';

void main() {
  final Finder retry = find.widgetWithText(FilledButton, AppStrings.retry);
  final Finder anotherNumber = find.widgetWithText(
    TextButton,
    AppStrings.useAnotherNumber,
  );

  Future<FakeAuthRepository> pumpError(
    WidgetTester tester, [
    AppErrorKind kind = AppErrorKind.network,
  ]) async {
    final FakeAuthRepository repository = FakeAuthRepository(userId: 'u')
      ..fetchError = AppException(kind);
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('loading: app name, spinner and text, no buttons', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      FakeAuthRepository(userId: 'u')..fetchGate = Completer<void>(),
    );
    await tester.pump();

    expect(find.byType(StartScreen), findsOneWidget);
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.startLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(retry, findsNothing);
  });

  for (final (AppErrorKind kind, String message) in <(AppErrorKind, String)>[
    (AppErrorKind.network, AppStrings.errorNoConnection),
    (AppErrorKind.unknown, AppStrings.errorUnknown),
    (AppErrorKind.permission, AppStrings.errorPermissionDenied),
  ]) {
    testWidgets('error ${kind.name}: message, retry and another number', (
      WidgetTester tester,
    ) async {
      await pumpError(tester, kind);

      expect(find.text(AppStrings.startErrorTitle), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(retry, findsOneWidget);
      expect(anotherNumber, findsOneWidget);
    });
  }

  testWidgets('retry shows the loading view while the name reloads', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = await pumpError(tester);
    repository
      ..fetchError = null
      ..fetchGate = Completer<void>();

    await tester.tap(retry);
    await tester.pump();

    expect(find.text(AppStrings.startLoading), findsOneWidget);
    expect(retry, findsNothing);
    expect(repository.fetchCalls, 2);

    repository.fetchError = const AppException(AppErrorKind.network);
    repository.fetchGate!.complete();
    await tester.pumpAndSettle();
    expect(retry, findsOneWidget);
  });

  testWidgets('another number signs out once and opens phone entry', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = await pumpError(tester);
    repository.signOutGate = Completer<void>();

    await tester.tap(anotherNumber);
    await tester.tap(anotherNumber);
    await tester.pump();
    expect(repository.signOutCalls, 1);
    expect(
      find.descendant(
        of: find.byType(TextButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(TextButton), warnIfMissed: false);
    await tester.pump();
    expect(repository.signOutCalls, 1);

    repository.signOutGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
  });

  testWidgets('a failed sign-out shows the Arabic message', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = await pumpError(tester);
    repository.signOutError = AuthRetryableFetchException(message: 'offline');

    await tester.tap(anotherNumber);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(AppStrings.errorNoConnection),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('offline'), findsNothing);
    expect(anotherNumber, findsOneWidget);
  });
}
