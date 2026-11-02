import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/asset_catalog.dart';
import 'asset_download_client.dart';

/// Owns only [root]. Neither this adapter nor its repair path knows the database.
class FileRequiredAssets implements RequiredAssets {
  FileRequiredAssets({
    required this.catalog,
    required this.root,
    required this.location,
    required this.client,
    Stopwatch Function()? createDownloadTimer,
  }) : _createDownloadTimer = createDownloadTimer ?? Stopwatch.new;

  final AssetCatalog catalog;
  final Directory root;
  final AssetLocation location;
  final AssetDownloadClient client;
  final Stopwatch Function() _createDownloadTimer;
  Future<void> _tail = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await work();
    } on AssetException {
      rethrow;
    } on FileSystemException {
      throw const AssetException(AssetFailure.storage);
    } catch (_) {
      throw const AssetException(AssetFailure.storage);
    } finally {
      done.complete();
    }
  }

  Future<Directory> _directory() async {
    // lstat on a path ending in '/' follows directory links on POSIX.
    final path = root.path.replaceFirst(RegExp(r'[/\\]+$'), '');
    final directory = Directory(path);
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const AssetException(AssetFailure.storage);
    }
    await directory.create(recursive: true);
    return Directory(await directory.resolveSymbolicLinks());
  }

  /// Reject links at every component, including ledger and temporary files.
  Future<File> _file(String path) async {
    if (!safeAssetPath(path)) throw const AssetException(AssetFailure.catalog);
    var directory = await _directory();
    final parts = path.split('/');
    for (final part in parts.take(parts.length - 1)) {
      final next = Directory.fromUri(directory.uri.resolve(part));
      final type = await FileSystemEntity.type(next.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) await next.create();
      if (await FileSystemEntity.type(next.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const AssetException(AssetFailure.storage);
      }
      directory = next;
    }
    final file = File.fromUri(directory.uri.resolve(parts.last));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const AssetException(AssetFailure.storage);
    }
    return file;
  }

  Future<Map<String, dynamic>> _ledger() async {
    final file = await _file('ledger.json');
    if (!await file.exists()) return {};
    // A broken ledger is rebuildable. File/directory permission errors are not.
    if (await file.length() > 128 * 1024) return {};
    try {
      final source = utf8.decode(await file.readAsBytes());
      final json = jsonDecode(source) as Map<String, dynamic>;
      return json['schema'] == 1
          ? json['installed'] as Map<String, dynamic>
          : {};
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> ledger) async {
    final target = await _file('ledger.json');
    final pending = await _file('ledger-pending.json');
    await pending.writeAsString(
      jsonEncode({'schema': 1, 'installed': ledger}),
      flush: true,
    );
    await pending.rename(target.path);
  }

  Map<String, Object> _record(PresentationAsset asset, FileStat stat) => {
    'revision': asset.revision,
    'path': asset.path,
    'sha256': asset.sha256,
    'bytes': stat.size,
    'modified': stat.modified.microsecondsSinceEpoch,
    'changed': stat.changed.microsecondsSinceEpoch,
  };

  Future<bool> _valid(
    PresentationAsset asset,
    Map<String, dynamic> ledger, {
    bool verify = false,
  }) async {
    final file = await _file(asset.path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size != asset.bytes) {
      ledger.remove(asset.key);
      return false;
    }
    final record = _record(asset, stat);
    final saved = ledger[asset.key];
    if (!verify &&
        saved is Map &&
        record.entries.every((entry) => saved[entry.key] == entry.value)) {
      return true;
    }
    if ((await sha256.bind(file.openRead()).first).toString() != asset.sha256) {
      ledger.remove(asset.key);
      return false;
    }
    // Detect replacement during verification; do not cache an unverified stat.
    final after = _record(asset, await file.stat());
    if (!record.entries.every((e) => after[e.key] == e.value)) {
      ledger.remove(asset.key);
      return false;
    }
    ledger[asset.key] = record;
    return true;
  }

  @override
  Future<List<String>> inspect({bool verifyAll = false}) =>
      _exclusive(() async {
        final ledger = await _ledger();
        final missing = <String>[];
        for (final asset in catalog.assets) {
          if (!await _valid(asset, ledger, verify: verifyAll)) {
            missing.add(asset.key);
          }
        }
        await _save(ledger);
        return missing;
      });

  @override
  Future<Uri> resolve(String key) => _exclusive(() async {
    final asset = catalog.asset(key);
    final ledger = await _ledger();
    if (!await _valid(asset, ledger)) {
      throw const AssetException(AssetFailure.integrity);
    }
    return (await _file(asset.path)).uri;
  });

  @override
  Future<void> download(
    void Function(AssetProgress) onProgress,
  ) => _exclusive(() async {
    final ledger = await _ledger();
    final total = catalog.assets.fold(0, (sum, asset) => sum + asset.bytes);
    var completed = 0;
    for (final asset in catalog.assets) {
      if (!await _valid(asset, ledger)) {
        final uri = location.url(asset.path);
        final target = await _file(asset.path);
        final pending = await _file(
          asset.path.replaceFirst('.png', '-pending.png'),
        );
        // A partial stream is never an installation or a trusted resume point.
        RandomAccessFile? output;
        try {
          output = await pending.open(mode: FileMode.write);
          var received = 0;
          final deadline = _createDownloadTimer()..start();
          try {
            await for (final chunk
                in client.open(uri).timeout(const Duration(seconds: 15))) {
              received += chunk.length;
              if (received > asset.bytes) {
                throw const AssetException(AssetFailure.integrity);
              }
              if (deadline.elapsed > const Duration(minutes: 2)) {
                throw const AssetException(AssetFailure.network);
              }
              await output.writeFrom(chunk);
              onProgress(AssetProgress(completed + received, total));
            }
          } on FileSystemException {
            rethrow;
          } on AssetException {
            rethrow;
          } catch (_) {
            throw const AssetException(AssetFailure.network);
          }
          await output.flush();
          await output.close();
          output = null;
          if (received != asset.bytes ||
              (await sha256.bind(pending.openRead()).first).toString() !=
                  asset.sha256) {
            throw const AssetException(AssetFailure.integrity);
          }
          // Sibling rename stays on one filesystem; ledger commits afterwards.
          await pending.rename(target.path);
          ledger[asset.key] = _record(asset, await target.stat());
          await _save(ledger);
        } finally {
          await output?.close();
          if (await pending.exists()) await pending.delete();
        }
      }
      completed += asset.bytes;
      onProgress(AssetProgress(completed, total));
    }
  });
}
