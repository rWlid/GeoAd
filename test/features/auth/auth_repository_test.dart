import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/features/auth/data/auth_repository.dart';
import 'package:geo_ad/features/profile/data/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/never_supabase_client.dart';

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  final List<String> calls = <String>[];
  String? signInEmail;
  String? signInPassword;
  String? signUpEmail;
  String? signUpPassword;
  Map<String, dynamic>? signUpData;

  Object? signInError;
  bool signInHangs = false;
  Object? signUpError;
  Session? signUpSession = _session();
  Object? signOutError;
  bool signOutClearsSession = true;
  Session? session;
  final StreamController<AuthState> authEvents =
      StreamController<AuthState>.broadcast();

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> get onAuthStateChange => authEvents.stream;

  @override
  User? get currentUser => session?.user;

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    calls.add('signIn');
    signInEmail = email;
    signInPassword = password;
    if (signInHangs) {
      return Completer<AuthResponse>().future;
    }
    if (signInError != null) {
      throw signInError!;
    }
    session = _session();
    return AuthResponse(session: session);
  }

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    calls.add('signUp');
    signUpEmail = email;
    signUpPassword = password;
    signUpData = data;
    if (signUpError != null) {
      throw signUpError!;
    }
    session = signUpSession;
    return AuthResponse(session: signUpSession, user: _user);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    calls.add('signOut');
    if (signOutClearsSession) {
      session = null;
    }
    if (signOutError != null) {
      throw signOutError!;
    }
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient(this.auth);

  @override
  final GoTrueClient auth;

  final _ProfilesTable profiles = _ProfilesTable();

  @override
  SupabaseQueryBuilder from(String table) {
    expect(table, 'profiles');
    return _FakeQueryBuilder(profiles);
  }
}

class _ProfilesTable {
  String? readColumns;
  final Map<String, Object> readFilters = <String, Object>{};
  PostgrestMap? row = <String, dynamic>{
    'name': 'خالد',
    'phone': '966511110001',
    'is_business': false,
    'business_name': null,
  };
  Object? readError;
  bool hangs = false;

  Map<dynamic, dynamic>? updateValues;
  final Map<String, Object> filters = <String, Object>{};
  String? selectColumns;

  PostgrestList rows = <PostgrestMap>[
    <String, dynamic>{'id': _user.id},
  ];
  Object? error;
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this._table);

  final _ProfilesTable _table;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    _table.readColumns = columns;
    return _FakeReadBuilder(_table);
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map<dynamic, dynamic> values) {
    _table.updateValues = values;
    return _FakeFilterBuilder(_table);
  }
}

class _FakeReadBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeReadBuilder(this._table);

  final _ProfilesTable _table;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    _table.readFilters[column] = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeResult<PostgrestMap?>(
        () => _table.hangs
            ? Completer<PostgrestMap?>().future
            : _table.readError == null
            ? Future<PostgrestMap?>.value(_table.row)
            : Future<PostgrestMap?>.error(_table.readError!),
      );
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  _FakeFilterBuilder(this._table);

  final _ProfilesTable _table;

  @override
  PostgrestFilterBuilder<dynamic> eq(String column, Object value) {
    _table.filters[column] = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    _table.selectColumns = columns;
    return _FakeResult<PostgrestList>(
      () => _table.hangs
          ? Completer<PostgrestList>().future
          : _table.error == null
          ? Future<PostgrestList>.value(_table.rows)
          : Future<PostgrestList>.error(_table.error!),
    );
  }
}

class _FakeResult<T> extends Fake implements PostgrestTransformBuilder<T> {
  _FakeResult(this._answer);

  final Future<T> Function() _answer;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => _answer().then(onValue, onError: onError);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _answer().timeout(timeLimit, onTimeout: onTimeout);
}

const User _user = User(
  id: '00000000-0000-0000-0000-00000000000a',
  appMetadata: <String, dynamic>{},
  userMetadata: <String, dynamic>{},
  aud: 'authenticated',
  createdAt: '2026-09-24T00:00:00Z',
);

Session _session() =>
    Session(accessToken: 'token', tokenType: 'bearer', user: _user);

const AuthApiException _invalidCredentials = AuthApiException(
  'Invalid login credentials',
  statusCode: '400',
  code: 'invalid_credentials',
);

Matcher _throwsKind(AppErrorKind kind) => throwsA(
  isA<AppException>().having((AppException e) => e.kind, 'kind', kind),
);

void main() {
  late _FakeGoTrueClient auth;
  late _FakeSupabaseClient client;
  late AuthRepository repository;

  setUp(() {
    auth = _FakeGoTrueClient();
    client = _FakeSupabaseClient(auth);
    repository = AuthRepository(client);
  });

  group('mockCredentialsFor (D-01)', () {
    test('seed user A gives the exact seed.sql strings', () {
      final MockCredentials credentials = mockCredentialsFor('966511110001');
      expect(credentials.email, '966511110001@phone.geoad.app');
      expect(credentials.password, 'geoad-mock-966511110001');
    });

    test('seed user B gives the exact seed.sql strings', () {
      final MockCredentials credentials = mockCredentialsFor('966511110002');
      expect(credentials.email, '966511110002@phone.geoad.app');
      expect(credentials.password, 'geoad-mock-966511110002');
    });
  });

  group('isValidMockCode', () {
    test('accepts any 4 digits, Latin, Arabic-Indic or Persian', () {
      for (final String code in <String>['0000', '1234', '٤٣٢١', '۱۲۳۴']) {
        expect(isValidMockCode(code), isTrue, reason: code);
      }
    });

    test('rejects anything that is not exactly 4 digits', () {
      for (final String code in <String>[
        '',
        '123',
        '12345',
        '12a4',
        '12 34',
        '-123',
      ]) {
        expect(isValidMockCode(code), isFalse, reason: code);
      }
    });
  });

  group('normalizeProfileName (D-05)', () {
    test('trims and accepts 2 to 40 characters', () {
      expect(normalizeProfileName('  خالد 	'), 'خالد');
      expect(normalizeProfileName('سع'), 'سع');
      expect(normalizeProfileName('أ' * 40), 'أ' * 40);
      expect(normalizeProfileName('Sara Al-Qahtani'), 'Sara Al-Qahtani');
    });

    test('rejects fewer than 2 or more than 40 characters after trim', () {
      for (final String name in <String>['', '   ', 'خ', ' خ ', 'أ' * 41]) {
        expect(normalizeProfileName(name), isNull, reason: name);
      }
    });

    test('counts code points like Postgres char_length', () {
      expect(normalizeProfileName('😀' * 20), '😀' * 20);
      expect(normalizeProfileName('😀' * 41), isNull);
    });
  });

  group('signInWithMockOtp', () {
    test('signs in an existing user with the derived credentials', () async {
      await repository.signInWithMockOtp(phone: '0511110001', code: '1234');

      expect(auth.calls, <String>['signIn']);
      expect(auth.signInEmail, '966511110001@phone.geoad.app');
      expect(auth.signInPassword, 'geoad-mock-966511110001');
    });

    test('normalizes Arabic digits and +966 before deriving', () async {
      await repository.signInWithMockOtp(
        phone: '+٩٦٦ ٥١ ١١١ ٠٠٠٢',
        code: '٠٠٠٠',
      );

      expect(auth.signInEmail, '966511110002@phone.geoad.app');
      expect(auth.signInPassword, 'geoad-mock-966511110002');
    });

    test('falls back to sign-up on invalid_credentials', () async {
      auth.signInError = _invalidCredentials;

      await repository.signInWithMockOtp(phone: '0599990099', code: '1234');

      expect(auth.calls, <String>['signIn', 'signUp']);
      expect(auth.signUpEmail, '966599990099@phone.geoad.app');
      expect(auth.signUpPassword, 'geoad-mock-966599990099');
      expect(auth.signUpData, <String, dynamic>{'phone': '966599990099'});
      expect(repository.currentSession, isNotNull);
    });

    test('does not sign up on other sign-in errors', () async {
      auth.signInError = const AuthApiException(
        'Request rate limit reached',
        statusCode: '429',
        code: 'over_request_rate_limit',
      );

      await expectLater(
        repository.signInWithMockOtp(phone: '0511110001', code: '1234'),
        _throwsKind(AppErrorKind.unknown),
      );
      expect(auth.calls, <String>['signIn']);
    });

    test('maps a network failure during sign-in to network', () async {
      auth.signInError = AuthRetryableFetchException(message: 'offline');

      await expectLater(
        repository.signInWithMockOtp(phone: '0511110001', code: '1234'),
        _throwsKind(AppErrorKind.network),
      );
      expect(auth.calls, <String>['signIn']);
    });

    testWidgets('gives up on a hung sign-in after requestTimeout', (
      WidgetTester tester,
    ) async {
      auth.signInHangs = true;

      await expectNetworkErrorAtTimeout(
        tester,
        () => repository.signInWithMockOtp(phone: '0511110001', code: '1234'),
      );
      expect(auth.calls, <String>['signIn']);
    });

    test('maps a network failure during sign-up to network', () async {
      auth.signInError = _invalidCredentials;
      auth.signUpError = const SocketException('Failed host lookup');

      await expectLater(
        repository.signInWithMockOtp(phone: '0599990099', code: '1234'),
        _throwsKind(AppErrorKind.network),
      );
    });

    test('maps a sign-up API error to unknown', () async {
      auth.signInError = _invalidCredentials;
      auth.signUpError = const AuthApiException(
        'User already registered',
        statusCode: '422',
        code: 'user_already_exists',
      );

      await expectLater(
        repository.signInWithMockOtp(phone: '0599990099', code: '1234'),
        _throwsKind(AppErrorKind.unknown),
      );
    });

    test('throws unknown when sign-up returns no session', () async {
      auth.signInError = _invalidCredentials;
      auth.signUpSession = null;

      await expectLater(
        repository.signInWithMockOtp(phone: '0599990099', code: '1234'),
        _throwsKind(AppErrorKind.unknown),
      );
      expect(auth.calls, <String>['signIn', 'signUp']);
    });

    test('rejects an invalid phone before any request', () async {
      await expectLater(
        repository.signInWithMockOtp(phone: '0112345678', code: '1234'),
        _throwsKind(AppErrorKind.invalidPhone),
      );
      expect(auth.calls, isEmpty);
    });

    test('rejects an invalid code before any request', () async {
      await expectLater(
        repository.signInWithMockOtp(phone: '0511110001', code: '123'),
        _throwsKind(AppErrorKind.invalidCode),
      );
      expect(auth.calls, isEmpty);
    });
  });

  group('session', () {
    test('currentSession reflects the auth client', () async {
      expect(repository.currentSession, isNull);
      await repository.signInWithMockOtp(phone: '0511110001', code: '1234');
      expect(repository.currentSession, isNotNull);
    });

    test('authStateChanges drops gotrue stream errors', () async {
      final List<AuthChangeEvent> events = <AuthChangeEvent>[];
      final List<Object> errors = <Object>[];
      final StreamSubscription<AuthState> subscription = repository
          .authStateChanges
          .listen(
            (AuthState state) => events.add(state.event),
            onError: errors.add,
          );

      auth.authEvents
        ..add(const AuthState(AuthChangeEvent.signedIn, null))
        ..addError(AuthRetryableFetchException(message: 'refresh offline'))
        ..add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();

      expect(events, <AuthChangeEvent>[
        AuthChangeEvent.signedIn,
        AuthChangeEvent.signedOut,
      ]);
      expect(errors, isEmpty);
      await subscription.cancel();
    });

    test('fetchProfile throws unknown when signed out', () async {
      await expectLater(
        repository.fetchProfile(),
        _throwsKind(AppErrorKind.unknown),
      );
    });
  });

  group('fetchProfile', () {
    setUp(() => auth.session = _session());

    test('reads the name and phone from the own row', () async {
      final Profile profile = await repository.fetchProfile();

      expect(profile.name, 'خالد');
      expect(profile.phone, '966511110001');
      expect(profile.isBusiness, isFalse);
      expect(
        client.profiles.readColumns,
        'name,phone,is_business,business_name',
      );
      expect(client.profiles.readFilters, <String, Object>{'id': _user.id});
    });

    test('a null name means the name step (D-02)', () async {
      client.profiles.row = <String, dynamic>{
        'name': null,
        'phone': '966511110001',
        'is_business': false,
      };

      expect((await repository.fetchProfile()).name, isNull);
    });

    test('reads the business columns (task 2.4)', () async {
      client.profiles.row = <String, dynamic>{
        'name': 'خالد',
        'phone': '966511110001',
        'is_business': true,
        'business_name': 'متجر النخبة',
      };

      final Profile profile = await repository.fetchProfile();

      expect(profile.isBusiness, isTrue);
      expect(profile.businessName, 'متجر النخبة');
    });

    for (final Map<String, dynamic> bad in <Map<String, dynamic>>[
      <String, dynamic>{'is_business': null},
      <String, dynamic>{'is_business': 'true'},
      <String, dynamic>{'is_business': true, 'business_name': 7},
    ]) {
      test('a malformed business column ($bad) maps to unknown', () async {
        client.profiles.row = <String, dynamic>{
          'name': 'خالد',
          'phone': '966511110001',
          ...bad,
        };

        await expectLater(
          repository.fetchProfile(),
          _throwsKind(AppErrorKind.unknown),
        );
      });
    }

    test('a missing row is an error, never the name step', () async {
      client.profiles.row = null;

      await expectLater(
        repository.fetchProfile(),
        _throwsKind(AppErrorKind.unknown),
      );
    });

    for (final Object? phone in <Object?>[null, '0511110001', 966511110001]) {
      test(
        'a phone that is not 9665XXXXXXXX ($phone) maps to unknown',
        () async {
          client.profiles.row = <String, dynamic>{
            'name': 'خالد',
            'phone': phone,
            'is_business': false,
          };

          await expectLater(
            repository.fetchProfile(),
            _throwsKind(AppErrorKind.unknown),
          );
        },
      );
    }

    test('maps a network failure to network', () async {
      client.profiles.readError = const SocketException('Failed host lookup');

      await expectLater(
        repository.fetchProfile(),
        _throwsKind(AppErrorKind.network),
      );
    });

    testWidgets('gives up on a hung read after requestTimeout', (
      WidgetTester tester,
    ) async {
      client.profiles.hangs = true;

      await expectNetworkErrorAtTimeout(tester, repository.fetchProfile);
    });
  });

  group('signOut', () {
    test('clears the session', () async {
      auth.session = _session();

      await repository.signOut();

      expect(auth.calls, <String>['signOut']);
      expect(repository.currentSession, isNull);
    });

    test('a failed server revoke still counts as signed out', () async {
      auth.session = _session();
      auth.signOutError = AuthRetryableFetchException(message: 'offline');

      await repository.signOut();

      expect(repository.currentSession, isNull);
    });

    test('throws when the session is still there after an error', () async {
      auth.session = _session();
      auth.signOutClearsSession = false;
      auth.signOutError = AuthRetryableFetchException(message: 'offline');

      await expectLater(
        repository.signOut(),
        _throwsKind(AppErrorKind.network),
      );
    });
  });
}
