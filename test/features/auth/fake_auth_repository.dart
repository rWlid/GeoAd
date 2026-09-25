import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/app.dart';
import 'package:geo_ad/core/router.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/features/auth/data/auth_repository.dart';
import 'package:geo_ad/features/auth/providers/auth_providers.dart';
import 'package:geo_ad/features/profile/data/profile.dart';
import 'package:geo_ad/features/profile/providers/profile_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/fake_profile_repository.dart';

class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository({
    this.userId,
    this.name,
    this.phone = '966511110001',
    this.emitInitialSession = true,
    this.isBusiness = false,
    this.businessName,
  });

  String? userId;

  String? name;

  String phone;

  final bool emitInitialSession;

  bool isBusiness;
  String? businessName;

  final StreamController<AuthState> _events =
      StreamController<AuthState>.broadcast();

  final List<({String phone, String code})> signInCalls =
      <({String phone, String code})>[];
  Completer<void>? signInGate;
  Object? signInError;

  int fetchCalls = 0;
  Completer<void>? fetchGate;
  Object? fetchError;

  int signOutCalls = 0;
  Completer<void>? signOutGate;
  Object? signOutError;

  void emit(AuthChangeEvent event) => _events.add(
    AuthState(event, userId == null ? null : _sessionFor(userId!)),
  );

  @override
  Stream<AuthState> get authStateChanges async* {
    if (emitInitialSession) {
      yield AuthState(
        AuthChangeEvent.initialSession,
        userId == null ? null : _sessionFor(userId!),
      );
    }
    yield* _events.stream;
  }

  @override
  Future<void> signInWithMockOtp({
    required String phone,
    required String code,
  }) async {
    signInCalls.add((phone: phone, code: code));
    await signInGate?.future;
    if (signInError != null) {
      throw signInError!;
    }
    userId = 'user-$phone';
    emit(AuthChangeEvent.signedIn);
  }

  @override
  Future<Profile> fetchProfile() async {
    fetchCalls++;
    await fetchGate?.future;
    if (fetchError != null) {
      throw fetchError!;
    }
    return Profile(
      name: name,
      phone: phone,
      isBusiness: isBusiness,
      businessName: businessName,
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await signOutGate?.future;
    if (signOutError != null) {
      throw signOutError!;
    }
    userId = null;
    emit(AuthChangeEvent.signedOut);
  }

  static Session _sessionFor(String id) => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: id,
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-09-24T00:00:00Z',
    ),
  );
}

const Key mapTabKey = Key('map-tab');

Future<void> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repository, {
  FakeProfileRepository? profiles,
  FakeLogoPicker? picker,
  FakeLogoCompressor? compressor,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? FakeProfileRepository(),
        ),
        logoPickerProvider.overrideWithValue(picker ?? FakeLogoPicker()),
        logoCompressorProvider.overrideWithValue(
          compressor ?? FakeLogoCompressor(),
        ),
        routerProvider.overrideWith(
          (Ref ref) =>
              buildRouter(ref, mapTab: const SizedBox.expand(key: mapTabKey)),
        ),
      ],
      child: const GeoAdApp(),
    ),
  );
}

Future<void> submitNameAsIndividual(WidgetTester tester, String name) async {
  await tester.enterText(
    find.widgetWithText(TextField, AppStrings.nameLabel),
    name,
  );
  await tester.tap(find.text(AppStrings.accountTypeIndividual));
  await tester.pump();
  await tester.tap(find.text(AppStrings.saveButton));
}

GoRouter routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GeoAdApp)))
        .read(routerProvider);

String locationOf(WidgetTester tester) =>
    routerOf(tester).state.matchedLocation;
