import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors.dart';
import '../../../core/utils/image_compress.dart';
import '../data/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (Ref ref) => ProfileRepository(Supabase.instance.client),
    );

final Provider<LogoCompressor> logoCompressorProvider =
    Provider<LogoCompressor>((Ref ref) => const LogoCompressor());

final Provider<LogoPicker> logoPickerProvider = Provider<LogoPicker>(
  (Ref ref) => const LogoPicker(),
);

class LogoPicker {
  const LogoPicker();

  Future<Uint8List?> pick() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      return await file?.readAsBytes();
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
  }
}
