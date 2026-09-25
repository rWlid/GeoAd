import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../constants.dart';
import '../errors.dart';

typedef ImageSize = ({int width, int height});

ImageSize fitWithin(ImageSize size, int maxSide) {
  final int longer = size.width > size.height ? size.width : size.height;
  if (longer <= maxSide) {
    return size;
  }
  final double scale = maxSide / longer;
  int side(int value) {
    final int scaled = (value * scale).round();
    return scaled < 1 ? 1 : scaled;
  }

  return (width: side(size.width), height: side(size.height));
}

const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

bool isPng(Uint8List bytes) {
  if (bytes.length < _pngSignature.length) {
    return false;
  }
  for (int i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) {
      return false;
    }
  }
  return true;
}

class CompressedImage {
  const CompressedImage(this.bytes, {required this.isPng});

  final Uint8List bytes;

  final bool isPng;

  String get extension => isPng ? 'png' : 'jpg';

  String get contentType => isPng ? 'image/png' : 'image/jpeg';
}

typedef ImageSizeDecoder = Future<ImageSize> Function(Uint8List bytes);

typedef ImageEncoder = Future<Uint8List> Function(
  Uint8List bytes, {
  required ImageSize size,
  required bool png,
});

class LogoCompressor {
  const LogoCompressor({
    this.decodeSize = decodeImageSize,
    this.encode = encodeImage,
  });

  final ImageSizeDecoder decodeSize;
  final ImageEncoder encode;

  Future<CompressedImage> compress(Uint8List original) async {
    final bool png = isPng(original);
    final ImageSize size;
    try {
      size = await decodeSize(original);
    } catch (error, stackTrace) {
      AppException.from(error, stackTrace);
      throw const AppException(AppErrorKind.logoUnreadable);
    }
    final Uint8List bytes;
    try {
      bytes = await encode(
        original,
        size: fitWithin(size, logoMaxSidePixels),
        png: png,
      );
    } catch (error, stackTrace) {
      AppException.from(error, stackTrace);
      throw const AppException(AppErrorKind.logoUnreadable);
    }
    if (bytes.lengthInBytes > maxUploadBytes) {
      throw const AppException(AppErrorKind.logoTooLarge);
    }
    return CompressedImage(bytes, isPng: png);
  }
}

Future<ImageSize> decodeImageSize(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    bytes,
  );
  final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
    buffer,
  );
  final ImageSize size = (width: descriptor.width, height: descriptor.height);
  descriptor.dispose();
  buffer.dispose();
  return size;
}

// re-encoding drops exif, which also strips any gps position
Future<Uint8List> encodeImage(
  Uint8List bytes, {
  required ImageSize size,
  required bool png,
}) {
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: size.width,
    minHeight: size.height,
    quality: 80,
    format: png ? CompressFormat.png : CompressFormat.jpeg,
  );
}
