import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/core/theme.dart';
import 'package:geo_ad/features/map/providers/map_providers.dart';
import 'package:geo_ad/features/map/ui/radius_sheet.dart';

final Finder slider = find.byType(Slider);
final Finder label = find.byKey(const ValueKey<String>('radius-label'));

String labelText(WidgetTester tester) => tester.widget<Text>(label).data!;

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer.test());

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: RadiusSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title, the current radius and both ends', (
    WidgetTester tester,
  ) async {
    container.read(searchRadiusProvider.notifier).set(3500);
    await pumpSheet(tester);

    expect(find.text(AppStrings.searchRadius), findsOneWidget);
    expect(labelText(tester), '3.5 كم');
    expect(find.text('1 كم'), findsOneWidget);
    expect(find.text('5 كم'), findsOneWidget);
    expect(tester.widget<Slider>(slider).divisions, 8);
  });

  testWidgets('a tap in the middle snaps to 3 km and sets the radius', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(slider);
    await tester.pumpAndSettle();

    expect(labelText(tester), '3 كم');
    expect(container.read(searchRadiusProvider), 3000);
    expect(container.read(radiusPreviewProvider), isNull);
  });

  testWidgets('while dragging, the label and preview move in 500 m steps and '
      'the radius waits for release', (WidgetTester tester) async {
    await pumpSheet(tester);
    final Rect track = tester.getRect(slider);

    final TestGesture drag = await tester.startGesture(track.center);
    await drag.moveBy(Offset(-track.width / 10, 0));
    await tester.pump();

    final int? preview = container.read(radiusPreviewProvider);
    expect(preview, isNotNull);
    expect(preview! % 500, 0, reason: 'snapped to a step');
    expect(preview, greaterThan(3000));
    expect(labelText(tester), matches(RegExp(r'^\d(\.5)? كم$')));
    expect(container.read(searchRadiusProvider), 2000);

    await drag.up();
    await tester.pumpAndSettle();

    expect(container.read(searchRadiusProvider), preview);
    expect(container.read(radiusPreviewProvider), isNull);
  });

  testWidgets('RTL: the right end is 1 km and the left end is 5 km', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);

    await tester.dragFrom(tester.getCenter(slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(labelText(tester), '5 كم');
    expect(container.read(searchRadiusProvider), 5000);

    await tester.dragFrom(tester.getCenter(slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(labelText(tester), '1 كم');
    expect(container.read(searchRadiusProvider), 1000);
  });
}
