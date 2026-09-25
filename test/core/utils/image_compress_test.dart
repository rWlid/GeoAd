import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/constants.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/utils/image_compress.dart';

final Uint8List pngBytes = Uint8List.fromList(<int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, //
]);
final Uint8List jpegBytes = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]);

Matcher throwsKind(AppErrorKind kind) => throwsA(
  isA<AppException>().having((AppException e) => e.kind, 'kind', kind),
);

({LogoCompressor compressor, List<({ImageSize size, bool png})> calls})
fakeCompressor({
  ImageSize size = (width: 2000, height: 1000),
  int outputBytes = 1000,
  bool decodeFails = false,
  bool encodeFails = false,
}) {
  final List<({ImageSize size, bool png})> calls =
      <({ImageSize size, bool png})>[];
  final LogoCompressor compressor = LogoCompressor(
    decodeSize: (Uint8List bytes) async {
      if (decodeFails) {
        throw Exception('not an image');
      }
      return size;
    },
    encode:
        (Uint8List bytes, {required ImageSize size, required bool png}) async {
          calls.add((size: size, png: png));
          if (encodeFails) {
            throw Exception('codec failed');
          }
          return Uint8List(outputBytes);
        },
  );
  return (compressor: compressor, calls: calls);
}

void main() {
  group('fitWithin', () {
    test('scales the longer side down to the limit, keeping the ratio', () {
      expect(fitWithin((width: 2000, height: 1000), 512), (
        width: 512,
        height: 256,
      ));
      expect(fitWithin((width: 1000, height: 4000), 512), (
        width: 128,
        height: 512,
      ));
      expect(fitWithin((width: 1024, height: 1024), 512), (
        width: 512,
        height: 512,
      ));
    });

    test('never upscales', () {
      expect(fitWithin((width: 300, height: 200), 512), (
        width: 300,
        height: 200,
      ));
      expect(fitWithin((width: 512, height: 100), 512), (
        width: 512,
        height: 100,
      ));
    });

    test('keeps at least 1 pixel on a very thin image', () {
      expect(fitWithin((width: 10000, height: 2), 512), (
        width: 512,
        height: 1,
      ));
    });
  });

  group('isPng', () {
    test('recognises the PNG signature, whatever the file was called', () {
      expect(isPng(pngBytes), isTrue);
      expect(isPng(jpegBytes), isFalse);
      expect(isPng(Uint8List(0)), isFalse);
      expect(isPng(Uint8List.fromList(<int>[137, 80, 78])), isFalse);
    });
  });

  test('CompressedImage gives the extension and the explicit content type', () {
    expect(CompressedImage(pngBytes, isPng: true).extension, 'png');
    expect(CompressedImage(pngBytes, isPng: true).contentType, 'image/png');
    expect(CompressedImage(jpegBytes, isPng: false).extension, 'jpg');
    expect(CompressedImage(jpegBytes, isPng: false).contentType, 'image/jpeg');
  });

  group('LogoCompressor', () {
    test('a PNG stays PNG, resized to 512 px on the longer side', () async {
      final fake = fakeCompressor(size: (width: 2000, height: 1000));

      final CompressedImage image = await fake.compressor.compress(pngBytes);

      expect(image.isPng, isTrue);
      expect(fake.calls.single.png, isTrue);
      expect(fake.calls.single.size, (width: 512, height: 256));
      expect(logoMaxSidePixels, 512);
    });

    test('anything else becomes JPEG', () async {
      final fake = fakeCompressor();

      final CompressedImage image = await fake.compressor.compress(jpegBytes);

      expect(image.isPng, isFalse);
      expect(fake.calls.single.png, isFalse);
    });

    test('a small logo is not upscaled', () async {
      final fake = fakeCompressor(size: (width: 200, height: 100));

      await fake.compressor.compress(pngBytes);

      expect(fake.calls.single.size, (width: 200, height: 100));
    });

    test('still above 5 MB after compressing: logoTooLarge, nothing to '
        'upload', () async {
      final fake = fakeCompressor(outputBytes: maxUploadBytes + 1);

      await expectLater(
        fake.compressor.compress(pngBytes),
        throwsKind(AppErrorKind.logoTooLarge),
      );
    });

    test('exactly 5 MB is still accepted', () async {
      final fake = fakeCompressor(outputBytes: maxUploadBytes);

      final CompressedImage image = await fake.compressor.compress(pngBytes);

      expect(image.bytes.lengthInBytes, maxUploadBytes);
    });

    test(
      'a file that is not an image: logoUnreadable, never encoded',
      () async {
        final fake = fakeCompressor(decodeFails: true);

        await expectLater(
          fake.compressor.compress(jpegBytes),
          throwsKind(AppErrorKind.logoUnreadable),
        );
        expect(fake.calls, isEmpty);
      },
    );

    test('a codec failure is logoUnreadable too', () async {
      final fake = fakeCompressor(encodeFails: true);

      await expectLater(
        fake.compressor.compress(jpegBytes),
        throwsKind(AppErrorKind.logoUnreadable),
      );
    });
  });
}
