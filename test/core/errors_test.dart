import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppException.from maps', () {
    final Map<String, (Object, AppErrorKind)> cases =
        <String, (Object, AppErrorKind)>{
          'SocketException → network': (
            const SocketException('Failed host lookup'),
            AppErrorKind.network,
          ),
          'TimeoutException → network': (
            TimeoutException('request timed out'),
            AppErrorKind.network,
          ),
          'AuthRetryableFetchException → network': (
            AuthRetryableFetchException(message: 'ClientException: offline'),
            AppErrorKind.network,
          ),
          'PostgrestException 42501 → permission': (
            const PostgrestException(message: 'not yours', code: '42501'),
            AppErrorKind.permission,
          ),
          'PostgrestException 22023 → validation': (
            const PostgrestException(message: 'empty list', code: '22023'),
            AppErrorKind.validation,
          ),
          'PostgrestException 23514 → validation': (
            const PostgrestException(message: 'check failed', code: '23514'),
            AppErrorKind.validation,
          ),
          'PostgrestException other code → unknown': (
            const PostgrestException(message: 'boom', code: '23505'),
            AppErrorKind.unknown,
          ),
          'PostgrestException without code → unknown': (
            const PostgrestException(message: 'boom'),
            AppErrorKind.unknown,
          ),
          'AuthApiException → unknown': (
            const AuthApiException(
              'Request rate limit reached',
              statusCode: '429',
              code: 'over_request_rate_limit',
            ),
            AppErrorKind.unknown,
          ),
          'StorageException 403 (folder rule) → permission': (
            const StorageException('denied', statusCode: '403'),
            AppErrorKind.permission,
          ),
          'StorageException 413 (over 5 MB) → logoTooLarge': (
            const StorageException('too large', statusCode: '413'),
            AppErrorKind.logoTooLarge,
          ),
          'StorageException 415 (not jpeg/png) → validation': (
            const StorageException('mime', statusCode: '415'),
            AppErrorKind.validation,
          ),
          'StorageException other status → unknown': (
            const StorageException('boom', statusCode: '500'),
            AppErrorKind.unknown,
          ),
          'FormatException → unknown': (
            const FormatException('bad json'),
            AppErrorKind.unknown,
          ),
          'a plain string → unknown': ('something', AppErrorKind.unknown),
        };

    cases.forEach((String name, (Object, AppErrorKind) testCase) {
      test(name, () {
        expect(AppException.from(testCase.$1).kind, testCase.$2);
      });
    });

    test('an AppException passes through unchanged', () {
      const AppException original = AppException(AppErrorKind.invalidPhone);
      expect(AppException.from(original), same(original));
    });
  });

  group('AppException.location (D-16)', () {
    test('maps a timeout to locationUnavailable, not network', () {
      expect(
        AppException.location(TimeoutException('no fix')).kind,
        AppErrorKind.locationUnavailable,
      );
    });

    test('maps any other failure to locationUnavailable', () {
      expect(
        AppException.location(const FormatException('bad')).kind,
        AppErrorKind.locationUnavailable,
      );
    });

    test('an AppException passes through unchanged', () {
      const AppException original = AppException(AppErrorKind.unknown);
      expect(AppException.location(original), same(original));
    });
  });

  group('AppException.message', () {
    test('is the Arabic string for each kind', () {
      const Map<AppErrorKind, String> expected = <AppErrorKind, String>{
        AppErrorKind.network: AppStrings.errorNoConnection,
        AppErrorKind.permission: AppStrings.errorPermissionDenied,
        AppErrorKind.validation: AppStrings.errorValidation,
        AppErrorKind.invalidPhone: AppStrings.errorInvalidPhone,
        AppErrorKind.invalidCode: AppStrings.errorInvalidCode,
        AppErrorKind.invalidName: AppStrings.errorInvalidName,
        AppErrorKind.invalidBusinessName: AppStrings.errorInvalidBusinessName,
        AppErrorKind.logoTooLarge: AppStrings.errorLogoTooLarge,
        AppErrorKind.logoUnreadable: AppStrings.errorLogoUnreadable,
        AppErrorKind.unknown: AppStrings.errorUnknown,
        AppErrorKind.locationUnavailable: AppStrings.errorLocationUnavailable,
      };
      expect(expected.keys, containsAll(AppErrorKind.values));
      expected.forEach((AppErrorKind kind, String message) {
        expect(AppException(kind).message, message);
      });
    });

    test('never contains the raw error text', () {
      const String raw = 'new row violates row-level security policy';
      final AppException mapped = AppException.from(
        const PostgrestException(message: raw, code: '42501'),
      );
      expect(mapped.message, isNot(contains(raw)));
      expect(mapped.toString(), isNot(contains(raw)));
    });
  });
}
