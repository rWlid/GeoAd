import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/constants.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/images_storage.dart';
import 'package:geo_ad/core/utils/image_compress.dart';
import 'package:geo_ad/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/never_supabase_client.dart';

const String _userId = '5eed0000-0000-4000-8000-0000000000ff';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class _FakeClient extends Fake implements SupabaseClient {
  final _FakeAuth _auth = _FakeAuth();
  final _FakeBucket bucket = _FakeBucket();

  final List<Map<dynamic, dynamic>> updates = <Map<dynamic, dynamic>>[];
  final Map<String, Object> filters = <String, Object>{};
  PostgrestList updateRows = <PostgrestMap>[
    <String, dynamic>{'id': _userId},
  ];
  Object? updateError;
  bool updateHangs = false;

  @override
  GoTrueClient get auth => _auth;

  @override
  SupabaseStorageClient get storage => _FakeStorage(bucket);

  @override
  SupabaseQueryBuilder from(String table) {
    expect(table, 'profiles');
    return _FakeQueryBuilder(this);
  }
}

class _FakeAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => const User(
    id: _userId,
    appMetadata: <String, dynamic>{},
    userMetadata: <String, dynamic>{},
    aud: 'authenticated',
    createdAt: '2026-09-24T00:00:00Z',
  );
}

class _FakeStorage extends Fake implements SupabaseStorageClient {
  _FakeStorage(this._bucket);

  final _FakeBucket _bucket;

  @override
  StorageFileApi from(String id) {
    expect(id, imagesBucket);
    return _bucket;
  }
}

class _FakeBucket extends Fake implements StorageFileApi {
  final List<({String path, Uint8List data, FileOptions options})> uploads =
      <({String path, Uint8List data, FileOptions options})>[];
  final List<List<String>> removes = <List<String>>[];
  Object? uploadError;
  bool uploadHangs = false;
  Object? removeError;
  bool removeFindsNothing = false;

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) {
    uploads.add((path: path, data: data, options: fileOptions));
    if (uploadHangs) {
      return Completer<String>().future;
    }
    if (uploadError != null) {
      return Future<String>.error(uploadError!);
    }
    return Future<String>.value('$imagesBucket/$path');
  }

  @override
  Future<List<FileObject>> remove(List<String> paths) async {
    removes.add(paths);
    if (removeError != null) {
      throw removeError!;
    }
    return removeFindsNothing
        ? <FileObject>[]
        : <FileObject>[
            for (final String path in paths)
              FileObject.fromJson(<String, dynamic>{'name': path}),
          ];
  }
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this._client);

  final _FakeClient _client;

  @override
  PostgrestFilterBuilder<dynamic> update(Map<dynamic, dynamic> values) {
    _client.updates.add(values);
    return _FakeFilterBuilder(_client);
  }
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  _FakeFilterBuilder(this._client);

  final _FakeClient _client;

  @override
  PostgrestFilterBuilder<dynamic> eq(String column, Object value) {
    _client.filters[column] = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    expect(columns, 'id');
    return _FakeResult<PostgrestList>(
      () => _client.updateHangs
          ? Completer<PostgrestList>().future
          : _client.updateError == null
          ? Future<PostgrestList>.value(_client.updateRows)
          : Future<PostgrestList>.error(_client.updateError!),
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

Matcher _throwsKind(AppErrorKind kind) => throwsA(
  isA<AppException>().having((AppException e) => e.kind, 'kind', kind),
);

final CompressedImage _png = CompressedImage(
  Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10, 0]),
  isPng: true,
);
final CompressedImage _jpeg = CompressedImage(
  Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0]),
  isPng: false,
);

void main() {
  late _FakeClient client;
  late ProfileRepository repository;

  setUp(() {
    client = _FakeClient();
    repository = ProfileRepository(client);
  });

  group('normalizeBusinessName', () {
    test('trims and accepts 2–50 characters', () {
      expect(normalizeBusinessName('  متجر النخبة  '), 'متجر النخبة');
      expect(normalizeBusinessName('أب'), 'أب');
      expect(normalizeBusinessName('ب' * 50), 'ب' * 50);
    });

    test('rejects fewer than 2 or more than 50 characters', () {
      expect(normalizeBusinessName(''), isNull);
      expect(normalizeBusinessName('   '), isNull);
      expect(normalizeBusinessName(' ب '), isNull);
      expect(normalizeBusinessName('ب' * 51), isNull);
    });

    test('counts code points like Postgres char_length', () {
      expect(normalizeBusinessName('بَ' * 25), isNotNull);
      expect(normalizeBusinessName('بَ' * 26), isNull);
    });
  });

  test('imageStoragePath puts the file in the user folder with its type', () {
    expect(imageStoragePath('u1', 'f1', _png), 'u1/f1.png');
    expect(imageStoragePath('u1', 'f1', _jpeg), 'u1/f1.jpg');
  });

  group('uploadLogo', () {
    test('uploads a PNG to {user_id}/{uuid}.png as image/png, never '
        'overwriting', () async {
      final String path = await repository.uploadLogo(_png);

      final ({String path, Uint8List data, FileOptions options}) upload =
          client.bucket.uploads.single;
      expect(upload.path, path);
      expect(path, startsWith('$_userId/'));
      expect(path, endsWith('.png'));
      expect(_uuidV4.hasMatch(path.split('/')[1].split('.').first), isTrue);
      expect(upload.data, _png.bytes);
      expect(upload.options.contentType, 'image/png');
      expect(upload.options.upsert, isFalse);
    });

    test('uploads a JPEG as .jpg with image/jpeg', () async {
      final String path = await repository.uploadLogo(_jpeg);

      expect(path, endsWith('.jpg'));
      expect(client.bucket.uploads.single.options.contentType, 'image/jpeg');
      expect(client.bucket.uploads.single.options.upsert, isFalse);
    });

    test('each upload gets a new file name', () async {
      final String first = await repository.uploadLogo(_png);
      final String second = await repository.uploadLogo(_png);

      expect(first, isNot(second));
    });

    test('above 5 MB: logoTooLarge before any request', () async {
      final CompressedImage huge = CompressedImage(
        Uint8List(maxUploadBytes + 1),
        isPng: true,
      );

      await expectLater(
        repository.uploadLogo(huge),
        _throwsKind(AppErrorKind.logoTooLarge),
      );
      expect(client.bucket.uploads, isEmpty);
    });

    for (final (String status, AppErrorKind kind) in <(String, AppErrorKind)>[
      ('403', AppErrorKind.permission),
      ('413', AppErrorKind.logoTooLarge),
      ('415', AppErrorKind.validation),
    ]) {
      test('a Storage $status maps to ${kind.name}', () async {
        client.bucket.uploadError = StorageException(
          'rejected',
          statusCode: status,
        );

        await expectLater(repository.uploadLogo(_png), _throwsKind(kind));
      });
    }

    testWidgets('gives up on a hung upload after requestTimeout', (
      WidgetTester tester,
    ) async {
      client.bucket.uploadHangs = true;

      await expectNetworkErrorAtTimeout(
        tester,
        () => repository.uploadLogo(_png),
      );
    });
  });

  group('completeOnboarding', () {
    test('individual: name and is_business false in one update on the own '
        'row', () async {
      final ({String name, String? businessName}) saved = await repository
          .completeOnboarding(name: '  خالد  ', isBusiness: false);

      expect(saved.name, 'خالد');
      expect(saved.businessName, isNull);
      expect(client.updates.single, <String, dynamic>{
        'name': 'خالد',
        'is_business': false,
      });
      expect(client.filters, <String, Object>{'id': _userId});
    });

    test('store: name, type, business name and logo in one update', () async {
      final ({String name, String? businessName}) saved = await repository
          .completeOnboarding(
            name: 'فهد ',
            isBusiness: true,
            businessName: ' متجر فهد ',
            logoPath: '$_userId/a.png',
          );

      expect(saved.name, 'فهد');
      expect(saved.businessName, 'متجر فهد');
      expect(client.updates.single, <String, dynamic>{
        'name': 'فهد',
        'is_business': true,
        'business_name': 'متجر فهد',
        'logo_path': '$_userId/a.png',
      });
    });

    test('store without a logo saves logo_path null', () async {
      await repository.completeOnboarding(
        name: 'فهد',
        isBusiness: true,
        businessName: 'متجر فهد',
      );

      expect(client.updates.single['logo_path'], isNull);
      expect(client.updates.single, contains('logo_path'));
    });

    test('an invalid name throws before any request', () async {
      await expectLater(
        repository.completeOnboarding(name: ' خ ', isBusiness: false),
        _throwsKind(AppErrorKind.invalidName),
      );
      expect(client.updates, isEmpty);
    });

    test('a store with an invalid business name throws before any '
        'request', () async {
      for (final String? business in <String?>[null, '', 'ب', 'ب' * 51]) {
        await expectLater(
          repository.completeOnboarding(
            name: 'فهد',
            isBusiness: true,
            businessName: business,
          ),
          _throwsKind(AppErrorKind.invalidBusinessName),
        );
      }
      expect(client.updates, isEmpty);
    });

    test('an update RLS filters out (no row) is a permission error', () async {
      client.updateRows = <PostgrestMap>[];

      await expectLater(
        repository.completeOnboarding(name: 'خالد', isBusiness: false),
        _throwsKind(AppErrorKind.permission),
      );
    });

    test('the CHECK (23514) maps to validation', () async {
      client.updateError = const PostgrestException(
        message: 'violates check constraint',
        code: '23514',
      );

      await expectLater(
        repository.completeOnboarding(name: 'خالد', isBusiness: false),
        _throwsKind(AppErrorKind.validation),
      );
    });

    test('maps a network failure to network', () async {
      client.updateError = const SocketException('Failed host lookup');

      await expectLater(
        repository.completeOnboarding(name: 'خالد', isBusiness: false),
        _throwsKind(AppErrorKind.network),
      );
    });

    testWidgets('gives up on a hung update after requestTimeout', (
      WidgetTester tester,
    ) async {
      client.updateHangs = true;

      await expectNetworkErrorAtTimeout(
        tester,
        () => repository.completeOnboarding(name: 'خالد', isBusiness: false),
      );
    });
  });

  group('deleteLogo', () {
    test('removes exactly that path', () async {
      await repository.deleteLogo('$_userId/a.png');

      expect(client.bucket.removes.single, <String>['$_userId/a.png']);
    });

    test('is best effort: an error or a missing file never throws', () async {
      client.bucket.removeError = const SocketException('offline');
      await repository.deleteLogo('$_userId/a.png');

      client.bucket
        ..removeError = null
        ..removeFindsNothing = true;
      await repository.deleteLogo('$_userId/b.png');

      expect(client.bucket.removes, hasLength(2));
    });
  });
}
