import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/phone.dart';
import '../../profile/data/profile.dart';

typedef MockCredentials = ({String email, String password});

MockCredentials mockCredentialsFor(String phone12) =>
    (email: '$phone12@phone.geoad.app', password: 'geoad-mock-$phone12');

final RegExp _fourDigits = RegExp(r'^\d{4}$');

bool isValidMockCode(String code) =>
    _fourDigits.hasMatch(toLatinDigits(code.trim()));

// counts code points to match char_length in the profiles.name CHECK.
String? normalizeProfileName(String name) {
  final String trimmed = name.trim();
  final int length = trimmed.runes.length;
  if (length < 2 || length > 40) {
    return null;
  }
  return trimmed;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static const String _invalidCredentials = 'invalid_credentials';

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange.handleError(
    (Object error, StackTrace stackTrace) {
      AppException.from(error, stackTrace);
    },
  );

  Future<void> signInWithMockOtp({
    required String phone,
    required String code,
  }) async {
    final String? phone12 = normalizeSaudiPhone(phone);
    if (phone12 == null) {
      throw const AppException(AppErrorKind.invalidPhone);
    }
    if (!isValidMockCode(code)) {
      throw const AppException(AppErrorKind.invalidCode);
    }
    final MockCredentials credentials = mockCredentialsFor(phone12);

    try {
      await _auth
          .signInWithPassword(
            email: credentials.email,
            password: credentials.password,
          )
          .timeout(requestTimeout);
      return;
    } on AuthApiException catch (error, stackTrace) {
      if (error.code != _invalidCredentials) {
        throw AppException.from(error, stackTrace);
      }
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }

    final AuthResponse response;
    try {
      response = await _auth
          .signUp(
            email: credentials.email,
            password: credentials.password,
            data: <String, dynamic>{'phone': phone12},
          )
          .timeout(requestTimeout);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
    if (response.session == null) {
      debugPrint(
        '!!! signUp returned no session: is "Confirm email" on? (D-01)',
      );
      throw const AppException(AppErrorKind.unknown);
    }
  }

  Future<Profile> fetchProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('!!! fetchProfile called while signed out');
      throw const AppException(AppErrorKind.unknown);
    }

    final Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select('name,phone,is_business,business_name')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(requestTimeout);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
    if (row == null) {
      debugPrint(
        '!!! No profiles row for ${user.id}: handle_new_user() did not run, '
        'or RLS hides the row (D-02)',
      );
      throw const AppException(AppErrorKind.unknown);
    }
    try {
      return Profile.fromJson(row);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error, stackTrace) {
      final AppException mapped = AppException.from(error, stackTrace);
      if (_auth.currentSession != null) {
        throw mapped;
      }
    }
  }
}
