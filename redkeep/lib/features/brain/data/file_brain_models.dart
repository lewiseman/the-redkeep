import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../domain/brain.dart';
import 'model_download.dart';

/// Owns brain-models/ and exactly named LiteRT caches for these model IDs.
/// No database, media ledger, or plugin registry is deleted.
class FileBrainModels implements BrainModelFiles {
  FileBrainModels({
    required this.root,
    required this.download,
    this.runtimeCacheRoot,
    Stopwatch Function()? createDownloadTimer,
  }) : _createDownloadTimer = createDownloadTimer ?? Stopwatch.new;
  final Directory root;
  final Directory? runtimeCacheRoot;
  final ModelDownload download;
  final Stopwatch Function() _createDownloadTimer;
  bool _busy = false;

  Future<T> _exclusive<T>(Future<T> Function() body) async {
    if (_busy) throw const BrainException(BrainFailure.busy);
    _busy = true;
    try {
      return await body();
    } on BrainException {
      rethrow;
    } on FileSystemException {
      throw const BrainException(BrainFailure.storage);
    } finally {
      _busy = false;
    }
  }

  Future<File> _file(BrainModel model, {bool partial = false}) async {
    if (!RegExp(r'^[a-z0-9][a-z0-9-]{0,99}$').hasMatch(model.id)) {
      throw const BrainException(BrainFailure.incompatible);
    }
    final directory = Directory(root.path.replaceFirst(RegExp(r'[/\\]+$'), ''));
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const BrainException(BrainFailure.storage);
    }
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/${model.id}.${partial ? 'part' : 'litertlm'}',
    );
    final kind = await FileSystemEntity.type(file.path, followLinks: false);
    if (kind != FileSystemEntityType.notFound &&
        kind != FileSystemEntityType.file) {
      throw const BrainException(BrainFailure.storage);
    }
    return file;
  }

  Future<bool> _valid(File file, BrainModel model) async {
    final before = await file.stat();
    if (before.type != FileSystemEntityType.file ||
        before.size != model.bytes) {
      return false;
    }
    // Large weight hashing must not block Flutter frames.
    final path = file.path;
    final digest = await Isolate.run(
      () async => (await sha256.bind(File(path).openRead()).first).toString(),
    );
    final after = await file.stat();
    return digest == model.sha256 &&
        after.type == FileSystemEntityType.file &&
        before.size == after.size &&
        before.modified == after.modified &&
        before.changed == after.changed;
  }

  Future<ModelFileState> _inspect(BrainModel model) async {
    final target = await _file(model);
    if (await target.exists()) {
      return await _valid(target, model)
          ? ModelFileState.available
          : ModelFileState.corrupt;
    }
    return await (await _file(model, partial: true)).exists()
        ? ModelFileState.interrupted
        : ModelFileState.missing;
  }

  @override
  Future<ModelFileState> inspect(BrainModel model) =>
      _exclusive(() => _inspect(model));

  @override
  Future<String> verifiedPath(BrainModel model) => _exclusive(() async {
    final state = await _inspect(model);
    if (state != ModelFileState.available) {
      throw BrainException(
        state == ModelFileState.corrupt
            ? BrainFailure.integrity
            : BrainFailure.missing,
      );
    }
    return (await _file(model)).path;
  });

  @override
  Future<void> install(
    BrainModel model,
    BrainCancellation cancellation,
    void Function(int bytes) onProgress,
  ) => _exclusive(() async {
    cancellation.check();
    if (await _inspect(model) == ModelFileState.available) return;
    final target = await _file(model);
    final partial = await _file(model, partial: true);
    RandomAccessFile? output;
    StreamIterator<List<int>>? input;
    try {
      output = await partial.open(mode: FileMode.write);
      var received = 0;
      final deadline = _createDownloadTimer()..start();
      input = StreamIterator(download.open(Uri.parse(model.url), cancellation));
      while (await Future.any([
        input.moveNext().timeout(const Duration(seconds: 30)),
        cancellation.whenCancelled.then<bool>((_) => false),
      ])) {
        cancellation.check();
        received += input.current.length;
        if (received > model.bytes) {
          throw const BrainException(BrainFailure.integrity);
        }
        if (deadline.elapsed > const Duration(hours: 1)) {
          throw const BrainException(BrainFailure.download);
        }
        await output.writeFrom(input.current);
        onProgress(received);
      }
      cancellation.check();
      await output.flush();
      await output.close();
      output = null;
      if (received != model.bytes || !await _valid(partial, model)) {
        throw const BrainException(BrainFailure.integrity);
      }
      cancellation.check();
      // Only verified complete weights are promoted; interrupted .part is never trusted.
      await partial.rename(target.path);
    } on BrainException {
      rethrow;
    } on FileSystemException {
      throw const BrainException(BrainFailure.storage);
    } catch (_) {
      cancellation.check();
      throw const BrainException(BrainFailure.download);
    } finally {
      await input?.cancel();
      await output?.close();
      if (await partial.exists()) await partial.delete();
    }
  });

  @override
  Future<void> remove(BrainModel model) => _exclusive(() async {
    for (final partial in [false, true]) {
      final file = await _file(model, partial: partial);
      if (await file.exists()) await file.delete();
    }
    final cacheRoot = runtimeCacheRoot;
    if (cacheRoot == null) return;
    final type = await FileSystemEntity.type(
      cacheRoot.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw const BrainException(BrainFailure.storage);
    }
    // Qualified 1.19.1 creates caches in app support. Match only this model's
    // basename, numeric file timestamp, pinned byte size, and known suffixes.
    final pattern = RegExp(
      '^${RegExp.escape(model.id)}\\.litertlm_[0-9]+_${model.bytes}'
      r'(?:\.xnnpack_cache|_mldrift_(?:program|weight)_cache\.bin)$',
    );
    await for (final entity in cacheRoot.list(followLinks: false)) {
      if (pattern.hasMatch(entity.uri.pathSegments.last)) {
        if (entity is! File) throw const BrainException(BrainFailure.storage);
        await entity.delete();
      }
    }
  });
}
