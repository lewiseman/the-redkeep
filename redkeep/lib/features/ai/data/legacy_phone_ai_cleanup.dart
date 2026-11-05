import 'dart:io';

/// Frees the removed phone model (about 614 MB). Matches only the app-owned
/// model folder and the LiteRT caches named after the pinned model.
Future<void> removeLegacyPhoneAiFiles(Directory support) async {
  final models = Directory('${support.path}/brain-models');
  if (await FileSystemEntity.type(models.path, followLinks: false) ==
      FileSystemEntityType.directory) {
    await models.delete(recursive: true);
  }
  if (!await support.exists()) return;
  final caches = RegExp(
    r'^qwen3-06b-int8-722a0a54\.litertlm_[0-9]+_613722264'
    r'(?:\.xnnpack_cache|_mldrift_(?:program|weight)_cache\.bin)$',
  );
  await for (final entity in support.list(followLinks: false)) {
    if (entity is File && caches.hasMatch(entity.uri.pathSegments.last)) {
      await entity.delete();
    }
  }
}
