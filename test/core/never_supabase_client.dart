import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/constants.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NeverSupabaseClient extends Fake implements SupabaseClient {
  final List<String> requests = <String>[];
  final List<Map<String, dynamic>?> rpcParams = <Map<String, dynamic>?>[];

  @override
  SupabaseQueryBuilder from(String table) {
    requests.add(table);
    return _NeverQueryBuilder();
  }

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) {
    requests.add('rpc:$fn');
    rpcParams.add(params);
    return _NeverBuilder<T>();
  }
}

class _NeverQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _NeverBuilder<PostgrestList>();

  @override
  PostgrestFilterBuilder<dynamic> delete() => _NeverBuilder<dynamic>();
}

class _NeverBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final Future<T> _never = Completer<T>().future;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) =>
      _NeverBuilder<PostgrestList>();

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => _never.then(onValue, onError: onError);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _never.timeout(timeLimit, onTimeout: onTimeout);
}

Future<void> expectNetworkErrorAtTimeout(
  WidgetTester tester,
  Future<Object?> Function() call,
) async {
  Object? error;
  bool settled = false;
  unawaited(
    call()
        .then<void>(
          (Object? _) {},
          onError: (Object e) {
            error = e;
          },
        )
        .whenComplete(() => settled = true),
  );

  await tester.pump(requestTimeout - const Duration(milliseconds: 1));
  expect(settled, isFalse, reason: 'still waiting before the timeout');

  await tester.pump(const Duration(milliseconds: 1));
  expect(settled, isTrue, reason: 'gave up at the timeout');
  expect(
    error,
    isA<AppException>().having(
      (AppException e) => e.kind,
      'kind',
      AppErrorKind.network,
    ),
  );
}
