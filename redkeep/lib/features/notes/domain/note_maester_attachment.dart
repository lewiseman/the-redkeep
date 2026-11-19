import 'dart:convert';
import 'dart:typed_data';

/// The most photos and files one Maester request carries.
const noteMaesterAttachmentLimit = 4;

/// The most text one attached file adds, in UTF-8 bytes.
const noteMaesterFileTextBytes = 32768;

/// File types the Maester reads as text. Photos are read as images.
const noteMaesterTextExtensions = ['txt', 'md', 'markdown', 'csv', 'json'];
const noteMaesterImageExtensions = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'heic',
  'heif',
];

/// What the Maester is asked when the person attaches something and sends
/// without saying what to do with it.
const noteMaesterAttachmentIntent =
    'Add what the attachments contain to the note.';

/// A photo or file sent with one Maester request. Held in memory only and
/// never kept with the note.
class NoteMaesterAttachment {
  /// [bytes] is the photo prepared for upload, as PNG.
  NoteMaesterAttachment.image(this.name, Uint8List this.bytes) : text = null;
  NoteMaesterAttachment.text(this.name, String this.text) : bytes = null;

  final String name;
  final Uint8List? bytes;
  final String? text;
  bool get isImage => bytes != null;
}

/// The words of a picked text file, or a [FormatException] saying why it
/// cannot be sent.
String readNoteMaesterText(Uint8List bytes) {
  if (bytes.length > noteMaesterFileTextBytes) {
    throw const FormatException(
      'This file is too long. Attach a text file under 32 KB.',
    );
  }
  final String text;
  try {
    text = utf8.decode(bytes).replaceFirst('﻿', '');
  } on FormatException {
    throw const FormatException('This file is not readable text.');
  }
  if (text.trim().isEmpty) {
    throw const FormatException('This file is empty.');
  }
  if (RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(text)) {
    throw const FormatException('This file is not readable text.');
  }
  return text;
}
