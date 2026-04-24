import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('modern package files exist', () {
    expect(File('pubspec.yaml').existsSync(), isTrue);
    expect(File('bin/dartmud.dart').existsSync(), isTrue);
    expect(File('lib/dartmud.dart').existsSync(), isTrue);
  });
}
