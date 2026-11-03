import 'dart:convert';

/// Former download keys now shipped in the app. Ignore stale source overrides
/// so existing build configuration remains usable without downloading them.
const bundledArtworkKeys = {'onboarding.background.ink'};

enum AssetFailure { catalog, configuration, storage, network, integrity }

class AssetException implements Exception {
  const AssetException(this.failure);
  final AssetFailure failure;
}

/// Release metadata only. No remote catalog lookup is part of startup.
class AssetCatalog {
  AssetCatalog._(this.pack, this.assets);
  final String pack;
  final List<PresentationAsset> assets;

  factory AssetCatalog.parse(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['schema'] != 1 ||
          !_identifier(json['pack']) ||
          (json['assets'] as List).isEmpty ||
          (json['assets'] as List).length > 100) {
        throw const FormatException();
      }
      final assets = (json['assets'] as List)
          .map((value) {
            final row = value as Map<String, dynamic>;
            final key = row['key'] as String;
            final revision = row['revision'] as String;
            final path = row['path'] as String;
            final bytes = row['bytes'] as int;
            final hash = row['sha256'] as String;
            final license = row['license'] as String;
            final provenance = row['provenance'] as String;
            if (!RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$').hasMatch(key) ||
                !_identifier(revision) ||
                !safeAssetPath(path) ||
                !RegExp(r'\.(png|webp|jpg|jpeg)$').hasMatch(path) ||
                path.contains('-pending.') ||
                bytes <= 0 ||
                bytes > 10 * 1024 * 1024 ||
                !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
                license.trim().isEmpty ||
                provenance.trim().isEmpty) {
              throw const FormatException();
            }
            return PresentationAsset(
              key: key,
              revision: revision,
              path: path,
              bytes: bytes,
              sha256: hash,
              license: license,
              provenance: provenance,
            );
          })
          .toList(growable: false);
      if (assets.map((e) => e.key).toSet().length != assets.length ||
          assets.map((e) => e.path).toSet().length != assets.length ||
          assets.fold(0, (sum, e) => sum + e.bytes) > 50 * 1024 * 1024) {
        throw const FormatException();
      }
      return AssetCatalog._(json['pack'] as String, List.unmodifiable(assets));
    } catch (_) {
      throw const AssetException(AssetFailure.catalog);
    }
  }

  PresentationAsset asset(String key) => assets.firstWhere(
    (asset) => asset.key == key,
    orElse: () => throw const AssetException(AssetFailure.catalog),
  );
}

bool _identifier(Object? value) =>
    value is String && RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(value);

bool safeAssetPath(String path) =>
    path.length <= 200 &&
    path
        .split('/')
        .every(
          (part) =>
              RegExp(r'^[a-z0-9][a-z0-9_-]*(\.[a-z0-9]+)?$').hasMatch(part),
        );

class PresentationAsset {
  const PresentationAsset({
    required this.key,
    required this.revision,
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.license,
    required this.provenance,
  });
  final String key;
  final String revision;
  final String path;
  final int bytes;
  final String sha256;
  final String license;
  final String provenance;
}

abstract interface class AssetResolver {
  /// Resolve a verified persistent file, never a cache or remote URL.
  Future<Uri> resolve(String key);
}

class AssetProgress {
  const AssetProgress(this.completedBytes, this.totalBytes);
  final int completedBytes;
  final int totalBytes;
}

abstract interface class RequiredAssets implements AssetResolver {
  Future<List<String>> inspect({bool verifyAll = false});
  Future<void> download(void Function(AssetProgress) onProgress);
}
