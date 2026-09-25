import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/auth/ui/name_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/fake_profile_repository.dart';
import 'fake_auth_repository.dart';

final Uint8List _logoBytes = Uint8List.fromList(<int>[
  137, 80, 78, 71, 13, 10, 26, 10, //
]);

void main() {
  final Finder nameField = find.widgetWithText(TextField, AppStrings.nameLabel);
  final Finder businessNameField = find.widgetWithText(
    TextField,
    AppStrings.businessNameLabel,
  );
  final Finder individual = find.text(AppStrings.accountTypeIndividual);
  final Finder store = find.text(AppStrings.accountTypeStore);
  final Finder save = find.widgetWithText(FilledButton, AppStrings.saveButton);
  final Finder busySpinner = find.descendant(
    of: find.byType(FilledButton),
    matching: find.byType(CircularProgressIndicator),
  );

  late FakeProfileRepository profiles;
  late FakeLogoPicker picker;
  late FakeLogoCompressor compressor;

  setUp(() {
    profiles = FakeProfileRepository();
    picker = FakeLogoPicker(_logoBytes);
    compressor = FakeLogoCompressor();
  });

  Future<void> pumpName(WidgetTester tester) async {
    await pumpApp(
      tester,
      FakeAuthRepository(userId: 'new'),
      profiles: profiles,
      picker: picker,
      compressor: compressor,
    );
    await tester.pumpAndSettle();
    expect(find.byType(NameScreen), findsOneWidget);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Arabic texts, both types unselected with the hint, '
      'no store fields, no back button', (WidgetTester tester) async {
    await pumpName(tester);

    expect(find.text(AppStrings.nameTitle), findsOneWidget);
    expect(find.text(AppStrings.nameHeading), findsOneWidget);
    expect(find.text(AppStrings.nameLabel), findsOneWidget);
    expect(find.text(AppStrings.accountTypeLabel), findsOneWidget);
    expect(find.text(AppStrings.accountTypeHint), findsOneWidget);
    final SegmentedButton<Object?> segments = tester.widget(
      find.byWidgetPredicate((Widget w) => w is SegmentedButton),
    );
    expect(segments.selected, isEmpty);
    expect(businessNameField, findsNothing);
    expect(find.text(AppStrings.businessLogoLabel), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('no type chosen: the error replaces the hint, nothing is sent', (
    WidgetTester tester,
  ) async {
    await pumpName(tester);

    await tester.enterText(nameField, 'خالد');
    await tapSave(tester);

    expect(find.text(AppStrings.errorAccountTypeRequired), findsOneWidget);
    expect(find.text(AppStrings.accountTypeHint), findsNothing);
    expect(profiles.log, isEmpty);

    await tester.tap(individual);
    await tester.pump();
    expect(
      find.text(AppStrings.errorAccountTypeRequired),
      findsNothing,
      reason: 'choosing a type clears the error',
    );
  });

  for (final (String name, String reason) in <(String, String)>[
    ('', 'empty'),
    ('   ', 'only spaces'),
    ('خ', 'one character'),
    ('  خ  ', 'one character after trim'),
    ('أ' * 41, '41 characters'),
  ]) {
    testWidgets('rejects a name that is $reason inline without a request', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);

      await tester.enterText(nameField, name);
      await tester.tap(individual);
      await tapSave(tester);

      expect(find.text(AppStrings.errorInvalidName), findsOneWidget);
      expect(profiles.log, isEmpty);
      expect(find.byType(NameScreen), findsOneWidget);
    });
  }

  testWidgets('typing clears the name error', (WidgetTester tester) async {
    await pumpName(tester);
    await tapSave(tester);
    expect(find.text(AppStrings.errorInvalidName), findsOneWidget);

    await tester.enterText(nameField, 'خا');
    await tester.pump();

    expect(find.text(AppStrings.errorInvalidName), findsNothing);
  });

  for (final (String input, String saved) in <(String, String)>[
    ('  خالد  ', 'خالد'),
    ('سع', 'سع'),
    ('أ' * 40, 'أ' * 40),
  ]) {
    testWidgets('individual: saves "${saved.length} chars" trimmed with the '
        'type in one call, then the tabs', (WidgetTester tester) async {
      await pumpName(tester);

      await tester.enterText(nameField, input);
      await tester.tap(individual);
      await tapSave(tester);

      expect(profiles.log, <String>['onboard:$saved:false:null:null']);
      expect(find.byKey(mapTabKey), findsOneWidget);
    });
  }

  group('store', () {
    Future<void> chooseStore(WidgetTester tester) async {
      await tester.enterText(nameField, 'فهد');
      await tester.tap(store);
      await tester.pumpAndSettle();
    }

    testWidgets('shows the business name and the optional logo', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);
      await chooseStore(tester);

      expect(businessNameField, findsOneWidget);
      expect(find.text(AppStrings.businessLogoLabel), findsOneWidget);
      expect(find.text(AppStrings.businessNoLogo), findsOneWidget);
    });

    testWidgets('the business name is required and checked before any '
        'request; the field stops at 50', (WidgetTester tester) async {
      await pumpName(tester);
      await chooseStore(tester);

      await tapSave(tester);
      expect(find.text(AppStrings.errorInvalidBusinessName), findsOneWidget);

      await tester.enterText(businessNameField, 'ب');
      await tester.pump();
      expect(
        find.text(AppStrings.errorInvalidBusinessName),
        findsNothing,
        reason: 'typing clears the error',
      );
      await tapSave(tester);
      expect(find.text(AppStrings.errorInvalidBusinessName), findsOneWidget);
      expect(profiles.log, isEmpty);

      await tester.enterText(businessNameField, 'ب' * 60);
      expect(
        tester.widget<TextField>(businessNameField).controller!.text,
        'ب' * 50,
      );
    });

    testWidgets('without a logo: one call with the type and business name', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);
      await chooseStore(tester);

      await tester.enterText(businessNameField, ' متجر فهد ');
      await tapSave(tester);

      expect(profiles.log, <String>['onboard:فهد:true:متجر فهد:null']);
      expect(find.byKey(mapTabKey), findsOneWidget);
    });

    testWidgets('with a logo: uploaded first, then one call with its path', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);
      await chooseStore(tester);

      await tester.enterText(businessNameField, 'متجر فهد');
      await tester.ensureVisible(find.text(AppStrings.businessPickLogo));
      await tester.tap(find.text(AppStrings.businessPickLogo));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.text(AppStrings.businessRemoveLogo), findsOneWidget);
      await tapSave(tester);

      expect(profiles.log, <String>[
        'upload',
        'onboard:فهد:true:متجر فهد:user/1.png',
      ]);
      expect(find.byKey(mapTabKey), findsOneWidget);
    });

    testWidgets('a failed save deletes the uploaded logo and stays on the '
        'step', (WidgetTester tester) async {
      profiles.onboardError = const AppException(AppErrorKind.network);
      await pumpName(tester);
      await chooseStore(tester);

      await tester.enterText(businessNameField, 'متجر فهد');
      await tester.ensureVisible(find.text(AppStrings.businessPickLogo));
      await tester.tap(find.text(AppStrings.businessPickLogo));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(profiles.log, <String>[
        'upload',
        'onboard:فهد:true:متجر فهد:user/1.png',
        'delete:user/1.png',
      ]);
      expect(find.text(AppStrings.errorNoConnection), findsOneWidget);
      expect(find.byType(NameScreen), findsOneWidget);
    });

    testWidgets('a logo picked, then removed, is not uploaded', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);
      await chooseStore(tester);

      await tester.enterText(businessNameField, 'متجر فهد');
      await tester.ensureVisible(find.text(AppStrings.businessPickLogo));
      await tester.tap(find.text(AppStrings.businessPickLogo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.businessRemoveLogo));
      await tester.pump();
      await tapSave(tester);

      expect(profiles.log, <String>['onboard:فهد:true:متجر فهد:null']);
    });

    testWidgets('a logo still over 5 MB shows the error and is not uploaded', (
      WidgetTester tester,
    ) async {
      compressor.error = const AppException(AppErrorKind.logoTooLarge);
      await pumpName(tester);
      await chooseStore(tester);

      await tester.ensureVisible(find.text(AppStrings.businessPickLogo));
      await tester.tap(find.text(AppStrings.businessPickLogo));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errorLogoTooLarge), findsOneWidget);
      expect(find.text(AppStrings.businessNoLogo), findsOneWidget);
    });

    testWidgets('switching back to "فرد" sends no business data or logo', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);
      await chooseStore(tester);
      await tester.enterText(businessNameField, 'متجر فهد');
      await tester.ensureVisible(find.text(AppStrings.businessPickLogo));
      await tester.tap(find.text(AppStrings.businessPickLogo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(individual);
      await tester.tap(individual);
      await tester.pumpAndSettle();
      expect(businessNameField, findsNothing);
      await tapSave(tester);

      expect(profiles.log, <String>['onboard:فهد:false:null:null']);
    });
  });

  testWidgets('loading: spinner, and a double tap saves once', (
    WidgetTester tester,
  ) async {
    await pumpName(tester);
    profiles.onboardGate = Completer<void>();

    await tester.enterText(nameField, 'خالد');
    await tester.tap(individual);
    await tester.pump();
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(busySpinner, findsOneWidget);
    expect(profiles.log, hasLength(1));

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(profiles.log, hasLength(1));

    profiles.onboardGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(mapTabKey), findsOneWidget);
  });

  for (final (Object error, String message) in <(Object, String)>[
    (
      const PostgrestException(
        message: 'violates check constraint "profiles_name_check"',
        code: '23514',
      ),
      AppStrings.errorValidation,
    ),
    (const AppException(AppErrorKind.validation), AppStrings.errorValidation),
    (
      const AppException(AppErrorKind.permission),
      AppStrings.errorPermissionDenied,
    ),
    (const AppException(AppErrorKind.network), AppStrings.errorNoConnection),
  ]) {
    testWidgets('error $error: Arabic SnackBar, stays on the name step', (
      WidgetTester tester,
    ) async {
      await pumpName(tester);
      profiles.onboardError = error;

      await tester.enterText(nameField, 'خالد');
      await tester.tap(individual);
      await tapSave(tester);

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('check constraint'), findsNothing);
      expect(busySpinner, findsNothing);
      expect(find.byType(NameScreen), findsOneWidget);
      expect(find.byKey(mapTabKey), findsNothing);
    });
  }
}
