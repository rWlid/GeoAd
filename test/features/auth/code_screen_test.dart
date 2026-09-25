import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/auth/ui/code_screen.dart';
import 'package:geo_ad/features/auth/ui/phone_screen.dart';

import 'fake_auth_repository.dart';

void main() {
  final Finder codeField = find.byType(TextField);
  final Finder signIn = find.widgetWithText(
    FilledButton,
    AppStrings.signInButton,
  );
  final Finder busySpinner = find.descendant(
    of: find.byType(FilledButton),
    matching: find.byType(CircularProgressIndicator),
  );

  Future<FakeAuthRepository> pumpCode(
    WidgetTester tester, {
    String? name = 'خالد',
  }) async {
    final FakeAuthRepository repository = FakeAuthRepository(name: name);
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0511110001');
    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    expect(find.byType(CodeScreen), findsOneWidget);
    return repository;
  }

  testWidgets('shows the phone as 05…, LTR, and no demo-code note', (
    WidgetTester tester,
  ) async {
    await pumpCode(tester);

    final Finder phone = find.text('0511110001');
    expect(phone, findsOneWidget);
    expect(tester.widget<Text>(phone).textDirection, TextDirection.ltr);
    expect(find.textContaining('نسخة تجريبية'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.text(AppStrings.changeNumber), findsOneWidget);
    expect(
      tester.widget<TextField>(codeField).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('the phone sits at the RTL start, under the heading', (
    WidgetTester tester,
  ) async {
    await pumpCode(tester);

    expect(
      tester.getTopRight(find.text('0511110001')).dx,
      moreOrLessEquals(
        tester.getTopRight(find.text(AppStrings.codeHeading)).dx,
      ),
    );
  });

  testWidgets('change number goes back to phone entry with the number', (
    WidgetTester tester,
  ) async {
    await pumpCode(tester);

    await tester.tap(find.text(AppStrings.changeNumber));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(find.byType(CodeScreen), findsNothing);
    expect(find.text('0511110001'), findsOneWidget);
  });

  testWidgets('the field keeps only digits, at most 4', (
    WidgetTester tester,
  ) async {
    await pumpCode(tester);

    await tester.enterText(codeField, '1a2b3c4d5');
    await tester.pump();

    expect(tester.widget<TextField>(codeField).controller!.text, '1234');
  });

  for (final String code in <String>['', '1', '123']) {
    testWidgets('rejects "$code" inline without a request', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = await pumpCode(tester);

      await tester.enterText(codeField, code);
      await tester.tap(signIn);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errorInvalidCode), findsOneWidget);
      expect(repository.signInCalls, isEmpty);
    });
  }

  for (final String code in <String>['1234', '٤٣٢١', '۱۲۳۴']) {
    testWidgets('accepts "$code" and signs in with the normalized phone', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = await pumpCode(tester);

      await tester.enterText(codeField, code);
      await tester.tap(signIn);
      await tester.pumpAndSettle();

      expect(repository.signInCalls.single.phone, '966511110001');
      expect(repository.signInCalls.single.code, code);
      expect(find.byKey(mapTabKey), findsOneWidget);
    });
  }

  testWidgets('loading: spinner, and a double tap signs in once', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = await pumpCode(tester);
    repository.signInGate = Completer<void>();

    await tester.enterText(codeField, '1234');
    await tester.tap(signIn);
    await tester.tap(signIn);
    await tester.pump();
    expect(busySpinner, findsOneWidget);
    expect(repository.signInCalls, hasLength(1));

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.signInCalls, hasLength(1));

    repository.signInGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(mapTabKey), findsOneWidget);
  });

  for (final (Object error, String message) in <(Object, String)>[
    (const SocketException('offline'), AppStrings.errorNoConnection),
    (const AppException(AppErrorKind.network), AppStrings.errorNoConnection),
    (const AppException(AppErrorKind.unknown), AppStrings.errorUnknown),
    (StateError('raw internal text'), AppStrings.errorUnknown),
  ]) {
    testWidgets('error ${error.runtimeType}: Arabic SnackBar, can retry', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = await pumpCode(tester);
      repository.signInError = error;

      await tester.enterText(codeField, '1234');
      await tester.tap(signIn);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('raw internal'), findsNothing);
      expect(find.textContaining('offline'), findsNothing);
      expect(busySpinner, findsNothing);
      expect(find.byType(CodeScreen), findsOneWidget);

      repository.signInError = null;
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      expect(repository.signInCalls, hasLength(2));
      expect(find.byKey(mapTabKey), findsOneWidget);
    });
  }
}
