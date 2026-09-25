import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../../core/images_storage.dart';
import '../../../core/utils/image_compress.dart';
import '../../auth/data/auth_repository.dart';

String? normalizeBusinessName(String name) {
  final String trimmed = name.trim();
  final int length = trimmed.runes.length;
  if (length < 2 || length > 50) {
    return null;
  }
  return trimmed;
}

class ProfileRepository {
  ProfileRepository(this._client) : _images = ImagesStorage(_client);

  final SupabaseClient _client;
  final ImagesStorage _images;

  String get _userId {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('!!! ProfileRepository called while signed out');
      throw const AppException(AppErrorKind.unknown);
    }
    return user.id;
  }

  Future<String> uploadLogo(CompressedImage image) async {
    if (image.bytes.lengthInBytes > maxUploadBytes) {
      throw const AppException(AppErrorKind.logoTooLarge);
    }
    return _images.upload(_userId, image);
  }

  // must stay one update: the router treats a non-null name as onboarded
  Future<({String name, String? businessName})> completeOnboarding({
    required String name,
    required bool isBusiness,
    String? businessName,
    String? logoPath,
  }) async {
    assert(isBusiness || logoPath == null, 'only a store has a logo');
    final String? trimmed = normalizeProfileName(name);
    if (trimmed == null) {
      throw const AppException(AppErrorKind.invalidName);
    }
    if (!isBusiness) {
      await _updateOwnRow(<String, dynamic>{
        'name': trimmed,
        'is_business': false,
      });
      return (name: trimmed, businessName: null);
    }
    final String? business = normalizeBusinessName(businessName ?? '');
    if (business == null) {
      throw const AppException(AppErrorKind.invalidBusinessName);
    }
    await _updateOwnRow(<String, dynamic>{
      'name': trimmed,
      'is_business': true,
      'business_name': business,
      'logo_path': logoPath,
    });
    return (name: trimmed, businessName: business);
  }

  Future<void> deleteLogo(String path) => _images.remove(<String>[path]);

  Future<void> _updateOwnRow(Map<String, dynamic> values) async {
    final String userId = _userId;
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _client
          .from('profiles')
          .update(values)
          .eq('id', userId)
          .select('id')
          .timeout(requestTimeout);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
    if (rows.isEmpty) {
      debugPrint(
        '!!! PERMISSION DENIED (RLS): profiles update for $userId '
        'changed no row',
      );
      throw const AppException(AppErrorKind.permission);
    }
  }
}
