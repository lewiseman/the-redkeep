import 'dart:isolate';

import 'package:image/image.dart' as image;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/storage_providers.dart';
import '../../../core/media/compress_image.dart';
import '../../../core/storage/app_database.dart';
import '../../ai/data/ai_provider_store.dart';
import '../../diary/data/prepare_diary_image.dart';
import '../domain/note_details.dart';

final noteMediaStoreProvider = Provider<NoteMediaStore>(
  (ref) => NoteMediaStore(
    ref.watch(appDatabaseProvider),
    encoder: ref.watch(photoEncoderProvider),
  ),
);

/// Immutable app-owned copies. Staging is journaled before touching files.
class NoteMediaStore {
  NoteMediaStore(
    this.db, {
    Future<Directory> Function()? support,
    bool? android,
    Future<LostDataResponse> Function()? retrieve,
    PhotoEncoder? encoder,
  }) : _encoder = encoder ?? encodeWebp,
       _support = support ?? getApplicationSupportDirectory,
       _android = android ?? Platform.isAndroid,
       _retrieve = retrieve ?? ImagePicker().retrieveLostData,
       _generation = db.writingGeneration;
  static const fileLimitBytes = 10 * 1024 * 1024;
  final bool _android;
  final PhotoEncoder _encoder;
  final Future<LostDataResponse> Function() _retrieve;
  static Future<void> _pickerTail = Future.value();
  Future<({String id, NoteAttachment attachment})?>? _recovering;
  Future<void> _pickerUpdate(String? value, {bool reset = false}) {
    final work = _pickerTail.then((_) async {
      if (!reset) _check();
      if (value == null) {
        await SecureAiProviders.storage.delete(key: pickerKey);
      } else {
        await SecureAiProviders.storage.write(key: pickerKey, value: value);
      }
    });
    _pickerTail = work.then<void>((_) {}, onError: (Object _) {});
    return work;
  }

  final AppDatabase db;
  final int _generation;
  final Future<Directory> Function() _support;
  static const pickerKey = 'redkeep.notes.picker';
  void _check() {
    if (db.writingBlocked || db.writingGeneration != _generation) {
      throw StateError('Notes session expired');
    }
  }

  static bool owns(String path) =>
      RegExp(r'^note_media/[a-zA-Z0-9_.-]+$').hasMatch(path);
  Future<File> file(String path) async {
    if (!owns(path)) throw const FormatException('Invalid note media');
    final root = await _support();
    final dir = Directory(p.join(root.path, 'note_media'));
    if (await FileSystemEntity.type(dir.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid media directory');
    }
    final f = File(p.join(root.path, path));
    if (await FileSystemEntity.type(f.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid media file');
    }
    return f;
  }

  Future<File?> resolve(String path) async {
    try {
      final f = await file(path);
      if (!await f.exists() || await f.length() > 40 * 1024 * 1024) return null;
      if (!path.endsWith('.scan.json')) {
        final digest = RegExp(r'-([0-9a-f]{64})\.[a-z0-9]+$')
            .firstMatch(path)?[1];
        if (digest != null &&
            sha256.convert(await f.readAsBytes()).toString() != digest) {
          return null;
        }
      }
      return f;
    } catch (_) {
      return null;
    }
  }

  Future<String> write(
    Uint8List bytes, {
    String extension = '.png',
    String? identity,
  }) async {
    _check();
    if (bytes.isEmpty || bytes.length > 40 * 1024 * 1024) {
      throw const FormatException('Use a file smaller than 40 MB.');
    }
    final digest = sha256.convert(bytes).toString();
    final ext = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension.toLowerCase())
        ? extension.toLowerCase()
        : '.bin';
    final stamp = identity ?? DateTime.now().microsecondsSinceEpoch.toString();
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(stamp)) {
      throw const FormatException('Invalid media identity');
    }
    final path = 'note_media/$stamp-$digest$ext';
    await db
        .into(db.noteMediaOps)
        .insertOnConflictUpdate(
          NoteMediaOpsCompanion.insert(
            path: path,
            created: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    final f = await file(path);
    _check();
    await f.parent.create(recursive: true);
    _check();
    await File('${f.path}.partial').writeAsBytes(bytes, flush: true);
    _check();
    await File('${f.path}.partial').rename(f.path);
    _check();
    return path;
  }

  /// Photos (except GIFs) are compressed to WebP from sources up to 40 MB;
  /// every other file, videos included, is copied unchanged up to 10 MB.
  Future<NoteAttachment> importPath(String path) async {
    _check();
    final source = File(path);
    final stat = await source.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size == 0 ||
        stat.size > photoSourceBytes) {
      throw const FormatException('Choose a readable file smaller than 40 MB.');
    }
    final header = await _header(source);
    final type =
        lookupMimeType(path, headerBytes: header) ?? 'application/octet-stream';
    final signature = imageSignature(header);
    final photo =
        type.startsWith('image/') &&
        signature != null &&
        signature != ImageSignature.gif;
    if (!photo && stat.size > fileLimitBytes) {
      throw const FormatException('Choose a file smaller than 10 MB.');
    }
    final bytes = await source.readAsBytes();
    _check();
    if (!photo) {
      final owned = await write(bytes, extension: p.extension(path));
      return NoteAttachment(path: owned, type: type, name: p.basename(path));
    }
    final compressed = await compressPhoto(bytes, encoder: _encoder);
    _check();
    return NoteAttachment(
      path: await write(compressed.bytes, extension: compressed.ext),
      type: compressed.mime,
      name: p.setExtension(p.basename(path), compressed.ext),
    );
  }

  static Future<Uint8List> _header(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(32);
    } finally {
      await raf.close();
    }
  }

  Future<List<NoteAttachment>> pickFiles() async {
    final selection = await FilePicker.pickFiles(type: FileType.any);
    final result = <NoteAttachment>[];
    for (final f in selection) {
      if (f.path != null) result.add(await importPath(f.path!));
    }
    return result;
  }

  Future<NoteAttachment?> pickPhoto(
    String noteId, {
    bool camera = false,
  }) async {
    _check();
    await _pickerUpdate(
      jsonEncode({
        'id': noteId,
        'created': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    final photo = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (photo == null) {
      await _pickerUpdate(null);
      return null;
    }
    final attachment = await importPath(photo.path);
    await _pickerUpdate(null);
    return attachment;
  }

  Future<Map<String, dynamic>?> _pendingPicker() async {
    _check();
    await _pickerTail;
    final raw = await SecureAiProviders.storage.read(key: pickerKey);
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(value['id'] as String) ||
        value['created'] is! int ||
        DateTime.now().millisecondsSinceEpoch - (value['created'] as int) >
            86400000) {
      await _pickerUpdate(null);
      return null;
    }
    return value;
  }

  Future<({String id, NoteAttachment attachment})?> pendingPhoto() =>
      _recovering ??= _recoverPendingPhoto().whenComplete(
        () => _recovering = null,
      );
  Future<({String id, NoteAttachment attachment})?>
  _recoverPendingPhoto() async {
    final pending = await _pendingPicker();
    if (pending == null) return null;
    if (pending['attachment'] is Map) {
      return (
        id: pending['id'] as String,
        attachment: NoteAttachment.fromMap(
          Map<String, dynamic>.from(pending['attachment'] as Map),
        ),
      );
    }
    if (!_android) return null;
    final lost = await _retrieve();
    _check();
    if (lost.files?.isNotEmpty != true) return null;
    final result = await importPath(lost.files!.first.path);
    await _pickerUpdate(jsonEncode({...pending, 'attachment': result.toMap()}));
    return (id: pending['id'] as String, attachment: result);
  }

  Future<NoteAttachment?> recoverPhoto(String noteId) async {
    final pending = await _pendingPicker();
    if (pending?['id'] != noteId) return null;
    final recovered = await pendingPhoto();
    if (recovered == null) return null;
    await _pickerUpdate(null);
    return recovered.attachment;
  }

  Future<NoteAttachment> rotate(NoteAttachment attachment) async {
    final f = await resolve(attachment.path);
    if (f == null) throw const FormatException('This image is unavailable.');
    final bytes = await f.readAsBytes();
    final rotated = await Isolate.run(() {
      final decoded = image.decodeImage(bytes);
      if (decoded == null || decoded.width * decoded.height > 40000000) {
        throw const FormatException('This image could not be rotated.');
      }
      return image.encodePng(
        image.copyRotate(image.bakeOrientation(decoded), angle: 90),
      );
    });
    final webp = await _encoder(
      rotated,
      longEdge: photoLongEdge,
      quality: photoQuality,
    );
    if (webp.isEmpty) {
      throw const FormatException('This image could not be rotated.');
    }
    return NoteAttachment(
      path: await write(webp, extension: '.webp'),
      type: 'image/webp',
      name: p.setExtension(attachment.filename, '.webp'),
    );
  }

  Future<void> open(NoteAttachment attachment) async {
    final f = await resolve(attachment.path);
    if (f == null) {
      throw const FormatException(
        'This file is unavailable on this device. Reattach it here.',
      );
    }
    final result = await OpenFilex.open(f.path, type: attachment.type);
    if (result.type != ResultType.done) {
      throw const FormatException('No installed app could open this file.');
    }
  }

  Future<void> reconcile() async {
    _check();
    final keep = <String>{};
    for (final row
        in await db.customSelect('SELECT details FROM notes').get()) {
      final details = NoteDetails.decode(row.read<String>('details'));
      keep.addAll(details.attachments.map((a) => a.path));
      if (details.background['image'] case final String path) keep.add(path);
    }
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    for (final op in await (db.select(
      db.noteMediaOps,
    )..where((r) => r.created.isSmallerThanValue(cutoff))).get()) {
      if (keep.contains(op.path)) continue;
      for (final suffix in ['', '.partial', '.scan.json']) {
        final f = await file('${op.path}$suffix');
        _check();
        if (await f.exists()) await f.delete();
      }
      await (db.delete(
        db.noteMediaOps,
      )..where((r) => r.path.equals(op.path))).go();
    }
  }

  Future<void> clearAll() async {
    final root = await _support();
    final dir = Directory(p.join(root.path, 'note_media'));
    if (await FileSystemEntity.type(dir.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await dir.delete(recursive: true);
    }
    await _pickerUpdate(null, reset: true);
  }
}
