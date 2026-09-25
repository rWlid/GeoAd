import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'constants.dart';
import 'errors.dart';
import 'utils/image_compress.dart';

// storage policies only allow writes under the user's own folder
String imageStoragePath(String userId, String fileId, CompressedImage image) =>
    '$userId/$fileId.${image.extension}';

class ImagesStorage {
  ImagesStorage(this._client);

  final SupabaseClient _client;

  StorageFileApi get _bucket => _client.storage.from(imagesBucket);

  Future<String> upload(String userId, CompressedImage image) async {
    final String path = imageStoragePath(userId, const Uuid().v4(), image);
    try {
      await _bucket
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: false,
            ),
          )
          .timeout(requestTimeout);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
    return path;
  }

  Future<void> remove(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    try {
      final List<FileObject> removed = await _bucket
          .remove(paths)
          .timeout(requestTimeout);
      if (removed.length < paths.length) {
        debugPrint(
          'ImagesStorage.remove: ${removed.length} of '
          '${paths.length} removed from $paths',
        );
      }
    } catch (error, stackTrace) {
      AppException.from(error, stackTrace);
    }
  }
}
