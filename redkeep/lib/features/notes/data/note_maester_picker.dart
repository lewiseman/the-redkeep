import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../diary/data/prepare_diary_image.dart';
import '../domain/note_maester_attachment.dart';

/// Where the Maester's attachments come from: the camera, the photo
/// library and the phone's files. Nothing picked is copied into the app.
final noteMaesterPickerProvider = Provider<NoteMaesterPicker>(
  (ref) => const DeviceNoteMaesterPicker(),
);

abstract interface class NoteMaesterPicker {
  /// A new photo, or none when the camera is closed.
  Future<NoteMaesterAttachment?> takePhoto();

  /// Up to [limit] photos from the library.
  Future<List<NoteMaesterAttachment>> choosePhotos({required int limit});

  /// Photos or text files from the phone's files.
  Future<List<NoteMaesterAttachment>> chooseFiles();
}

class DeviceNoteMaesterPicker implements NoteMaesterPicker {
  const DeviceNoteMaesterPicker();

  // Large enough to read a page; the upload is resized again before sending.
  static const _side = 2560.0;

  @override
  Future<NoteMaesterAttachment?> takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: _side,
      maxHeight: _side,
    );
    if (photo == null) return null;
    return _image(p.basename(photo.path), await photo.readAsBytes());
  }

  @override
  Future<List<NoteMaesterAttachment>> choosePhotos({required int limit}) async {
    if (limit < 1) return const [];
    final photos = limit == 1
        ? [
            ?await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: _side,
              maxHeight: _side,
            ),
          ]
        : await ImagePicker().pickMultiImage(
            maxWidth: _side,
            maxHeight: _side,
            limit: limit,
          );
    return [
      for (final photo in photos.take(limit))
        await _image(p.basename(photo.path), await photo.readAsBytes()),
    ];
  }

  @override
  Future<List<NoteMaesterAttachment>> chooseFiles() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...noteMaesterImageExtensions,
        ...noteMaesterTextExtensions,
      ],
    );
    return [
      for (final file in picked)
        if (file.path != null) await _file(File(file.path!), file.name),
    ];
  }

  static Future<NoteMaesterAttachment> _image(
    String name,
    Uint8List bytes,
  ) async => NoteMaesterAttachment.image(name, await prepareImageBytes(bytes));

  static Future<NoteMaesterAttachment> _file(File file, String name) async {
    final size = await file.length();
    if (size > noteImageSourceBytes) {
      throw const FormatException('Choose a file smaller than 40 MB.');
    }
    final bytes = await file.readAsBytes();
    if (imageSignature(bytes) != null) return _image(name, bytes);
    final extension = p.extension(name).replaceFirst('.', '').toLowerCase();
    if (!noteMaesterTextExtensions.contains(extension)) {
      throw const FormatException(
        'Attach a photo or a text file (.txt, .md, .csv or .json).',
      );
    }
    return NoteMaesterAttachment.text(name, readNoteMaesterText(bytes));
  }
}
