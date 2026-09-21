import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Finish asset IO before fake-clock animation/screenshot tests begin.
  for (final site in ['ao3', 'ffn']) {
    await SvgAssetLoader('assets/sites/$site.svg').loadBytes(null);
  }
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _RasterComparator(
      comparator.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

class _RasterComparator extends LocalFileComparator {
  _RasterComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final expected = Uint8List.fromList(await getGoldenBytes(golden));
    final codecs = await Future.wait([
      ui.instantiateImageCodec(imageBytes),
      ui.instantiateImageCodec(expected),
    ]);
    final actualImage = (await codecs[0].getNextFrame()).image;
    final expectedImage = (await codecs[1].getNextFrame()).image;
    try {
      if (actualImage.width == expectedImage.width &&
          actualImage.height == expectedImage.height) {
        final actual = (await actualImage.toByteData())!.buffer.asUint8List();
        final reference = (await expectedImage.toByteData())!.buffer
            .asUint8List();
        if (rasterDifferencesAreMinor(actual, reference)) return true;
      }
    } finally {
      actualImage.dispose();
      expectedImage.dispose();
      for (final codec in codecs) {
        codec.dispose();
      }
    }
    return super.compare(imageBytes, golden);
  }
}

// macOS rasterizer versions differ slightly at antialiased edges. Require both
// a small affected area and a bounded channel delta; missing text/icons and
// shifted layouts must still fail. CI measurements are recorded in verification.
bool rasterDifferencesAreMinor(Uint8List actual, Uint8List reference) {
  if (actual.length != reference.length || actual.length % 4 != 0) return false;
  var changed = 0;
  for (var i = 0; i < actual.length; i += 4) {
    var differs = false;
    for (var channel = 0; channel < 4; channel++) {
      final delta = (actual[i + channel] - reference[i + channel]).abs();
      if (delta > 48) return false;
      differs |= delta != 0;
    }
    if (differs) changed++;
  }
  return changed <= (actual.length ~/ 4) * 0.0035;
}
