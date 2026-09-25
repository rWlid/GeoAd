import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'strings_ar.dart';

enum AppErrorKind {
  network,
  permission,
  validation,
  invalidPhone,
  invalidCode,
  invalidName,
  invalidBusinessName,
  logoTooLarge,
  logoUnreadable,
  unknown,
  locationUnavailable,
}

class AppException implements Exception {
  const AppException(this.kind);

  factory AppException.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }
    final AppErrorKind kind = _kindOf(error);
    _log(kind, error, stackTrace);
    return AppException(kind);
  }

  factory AppException.location(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }
    _log(AppErrorKind.locationUnavailable, error, stackTrace);
    return const AppException(AppErrorKind.locationUnavailable);
  }

  final AppErrorKind kind;

  String get message => switch (kind) {
    AppErrorKind.network => AppStrings.errorNoConnection,
    AppErrorKind.permission => AppStrings.errorPermissionDenied,
    AppErrorKind.validation => AppStrings.errorValidation,
    AppErrorKind.invalidPhone => AppStrings.errorInvalidPhone,
    AppErrorKind.invalidCode => AppStrings.errorInvalidCode,
    AppErrorKind.invalidName => AppStrings.errorInvalidName,
    AppErrorKind.invalidBusinessName => AppStrings.errorInvalidBusinessName,
    AppErrorKind.logoTooLarge => AppStrings.errorLogoTooLarge,
    AppErrorKind.logoUnreadable => AppStrings.errorLogoUnreadable,
    AppErrorKind.unknown => AppStrings.errorUnknown,
    AppErrorKind.locationUnavailable => AppStrings.errorLocationUnavailable,
  };

  @override
  String toString() => 'AppException(${kind.name})';

  static void _log(AppErrorKind kind, Object error, StackTrace? stackTrace) {
    final String tag = kind == AppErrorKind.permission
        ? '!!! PERMISSION DENIED (RLS/RPC)'
        : 'AppException';
    debugPrint('$tag [${kind.name}] ${error.runtimeType}: $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  static AppErrorKind _kindOf(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is AuthRetryableFetchException) {
      return AppErrorKind.network;
    }
    if (error is PostgrestException) {
      return switch (error.code) {
        '42501' => AppErrorKind.permission,
        '22023' || '23514' => AppErrorKind.validation,
        _ => AppErrorKind.unknown,
      };
    }
    if (error is StorageException) {
      return switch (error.statusCode) {
        '401' || '403' => AppErrorKind.permission,
        '413' => AppErrorKind.logoTooLarge,
        '400' || '415' => AppErrorKind.validation,
        _ => AppErrorKind.unknown,
      };
    }
    return AppErrorKind.unknown;
  }
}
