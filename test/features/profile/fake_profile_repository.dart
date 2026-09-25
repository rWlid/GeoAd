import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/utils/image_compress.dart';
import 'package:geo_ad/features/profile/data/profile_repository.dart';
import 'package:geo_ad/features/profile/providers/profile_providers.dart';

class FakeProfileRepository extends Fake implements ProfileRepository {
  final List<String> log = <String>[];
  int _files = 0;

  Completer<void>? onboardGate;
  Object? onboardError;

  @override
  Future<String> uploadLogo(CompressedImage image) async {
    log.add('upload');
    return 'user/${++_files}.${image.extension}';
  }

  @override
  Future<({String name, String? businessName})> completeOnboarding({
    required String name,
    required bool isBusiness,
    String? businessName,
    String? logoPath,
  }) async {
    final String trimmed = name.trim();
    final String? business = businessName?.trim();
    log.add('onboard:$trimmed:$isBusiness:$business:$logoPath');
    await onboardGate?.future;
    if (onboardError != null) {
      throw onboardError!;
    }
    return (name: trimmed, businessName: business);
  }

  @override
  Future<void> deleteLogo(String path) async => log.add('delete:$path');
}

class FakeLogoPicker extends Fake implements LogoPicker {
  FakeLogoPicker([this.bytes]);

  Uint8List? bytes;
  int calls = 0;

  @override
  Future<Uint8List?> pick() async {
    calls++;
    return bytes;
  }
}

class FakeLogoCompressor extends Fake implements LogoCompressor {
  Object? error;

  @override
  Future<CompressedImage> compress(Uint8List original) async {
    if (error != null) {
      throw error!;
    }
    return CompressedImage(original, isPng: true);
  }
}
