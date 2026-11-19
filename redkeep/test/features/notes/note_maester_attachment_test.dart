import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/domain/note_maester_attachment.dart';

void main() {
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test('text files are read as their words, without a byte order mark', () {
    expect(readNoteMaesterText(bytes('﻿eggs\nmilk\r\n')), 'eggs\nmilk\r\n');
  });

  test('binary, empty and long files are refused with a reason', () {
    for (final (file, reason) in [
      (Uint8List.fromList([0xff, 0xfe, 0x00]), 'not readable'),
      (bytes('a\u0000b'), 'not readable'),
      (bytes('  \n'), 'empty'),
      (bytes('x' * (noteMaesterFileTextBytes + 1)), 'too long'),
    ]) {
      expect(
        () => readNoteMaesterText(file),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(reason),
          ),
        ),
      );
    }
  });
}
