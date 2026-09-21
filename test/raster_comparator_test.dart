import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart';

void main() {
  test('raster allowance rejects missing content and broad color changes', () {
    final reference = Uint8List(4000);
    final subtleEdge = Uint8List(4000)..[0] = 32;
    expect(rasterDifferencesAreMinor(subtleEdge, reference), isTrue);
    final missingContent = Uint8List(4000)..[0] = 255;
    expect(rasterDifferencesAreMinor(missingContent, reference), isFalse);
    final broadChange = Uint8List(4000);
    for (var i = 0; i < 16; i += 4) {
      broadChange[i] = 1;
    }
    expect(rasterDifferencesAreMinor(broadChange, reference), isFalse);
    expect(rasterDifferencesAreMinor(Uint8List(4), reference), isFalse);
  });
}
