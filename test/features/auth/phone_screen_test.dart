import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/router.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/auth/ui/code_screen.dart';
import 'package:geo_ad/features/auth/ui/phone_screen.dart';

import 'fake_auth_repository.dart';

void main() {
  final Finder field = find.byType(TextField);
  final Finder continueButton = find.text(AppStrings.continueButton);

  Future<void> pumpPhone(WidgetTester tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
  }

  testWidgets('shows the Arabic texts and an LTR phone field', (
    WidgetTester tester,
  ) async {
    await pumpPhone(tester);

    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.phoneHeading), findsOneWidget);
    expect(find.text(AppStrings.phoneLabel), findsOneWidget);
    expect(tester.widget<TextField>(field).textDirection, TextDirection.ltr);
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.phone);
    expect(
      Directionality.of(tester.element(find.text(AppStrings.phoneHeading))),
      TextDirection.rtl,
    );
  });

  for (final String input in <String>['', '0112345678', '051111000', 'abc']) {
    testWidgets('rejects "$input" inline and stays', (
      WidgetTester tester,
    ) async {
      await pumpPhone(tester);

      await tester.enterText(field, input);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errorInvalidPhone), findsOneWidget);
      expect(find.byType(CodeScreen), findsNothing);
    });
  }

  testWidgets('typing clears the error', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errorInvalidPhone), findsOneWidget);

    await tester.enterText(field, '05');
    await tester.pump();

    expect(find.text(AppStrings.errorInvalidPhone), findsNothing);
  });

  for (final String input in <String>[
    '0511110001',
    '٠٥١١١١٠٠٠١',
    '+966 51 111 0001',
    '511110001',
  ]) {
    testWidgets('"$input" opens the code screen with the normalized phone', (
      WidgetTester tester,
    ) async {
      await pumpPhone(tester);

      await tester.enterText(field, input);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(
        tester.widget<CodeScreen>(find.byType(CodeScreen)).phone12,
        '966511110001',
      );
      expect(locationOf(tester), Routes.loginCode);
    });
  }

  testWidgets('the keyboard action submits too', (WidgetTester tester) async {
    await pumpPhone(tester);

    await tester.enterText(field, '0511110002');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(CodeScreen), findsOneWidget);
  });
}
