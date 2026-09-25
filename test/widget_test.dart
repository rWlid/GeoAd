import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/router.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/my_ads/my_ads_screen.dart';

import 'features/auth/fake_auth_repository.dart';

void main() {
  Future<void> pumpTabs(WidgetTester tester) async {
    await pumpApp(tester, FakeAuthRepository(userId: 'user-a', name: 'خالد'));
    await tester.pumpAndSettle();
    routerOf(tester).go(Routes.myAds);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the three Arabic tabs in RTL', (
    WidgetTester tester,
  ) async {
    await pumpTabs(tester);

    expect(find.text(AppStrings.tabMap), findsOneWidget);
    expect(find.text(AppStrings.tabMyAds), findsWidgets);
    expect(find.text(AppStrings.tabAccount), findsWidgets);

    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.rtl,
    );
  });

  testWidgets('the keyboard covers the map tab instead of shrinking it; '
      'the other tabs still resize (D-45)', (WidgetTester tester) async {
    await pumpApp(tester, FakeAuthRepository(userId: 'user-a', name: 'خالد'));
    await tester.pumpAndSettle();
    addTearDown(tester.view.resetViewInsets);
    final Size before = tester.getSize(find.byKey(mapTabKey));

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(mapTabKey)), before);

    routerOf(tester).go(Routes.myAds);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Scaffold>(
            find.ancestor(
              of: find.byType(NavigationBar),
              matching: find.byType(Scaffold),
            ),
          )
          .resizeToAvoidBottomInset,
      isTrue,
    );
  });

  testWidgets('the my-ads tab is an empty screen', (WidgetTester tester) async {
    await pumpTabs(tester);

    final Finder body = find.descendant(
      of: find.byType(MyAdsScreen),
      matching: find.byType(Text),
    );
    expect(
      tester.widgetList<Text>(body).map((Text text) => text.data),
      <String>[AppStrings.tabMyAds],
    );
  });

  testWidgets('switches to the account tab', (WidgetTester tester) async {
    await pumpTabs(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.logoutButton), findsOneWidget);
  });

  testWidgets('a store account labels the last tab as the store', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      FakeAuthRepository(
        userId: 'user-a',
        name: 'خالد',
        isBusiness: true,
        businessName: 'متجر النخبة',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.tabStore), findsOneWidget);
    expect(find.text(AppStrings.tabAccount), findsNothing);
  });
}
