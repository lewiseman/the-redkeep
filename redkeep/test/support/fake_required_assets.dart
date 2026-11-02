import 'dart:io';

import 'package:redkeep/features/assets/domain/asset_catalog.dart';

class FakeRequiredAssets implements RequiredAssets {
  List<String> missing = [];
  Object? checkError;
  Object? downloadError;
  int checks = 0;
  int downloads = 0;
  bool? verifyAll;
  void Function()? onDownload;

  @override
  Future<List<String>> inspect({bool verifyAll = false}) async {
    checks++;
    this.verifyAll = verifyAll;
    if (checkError case final error?) throw error;
    return missing;
  }

  @override
  Future<void> download(void Function(AssetProgress) onProgress) async {
    downloads++;
    onDownload?.call();
    onProgress(const AssetProgress(1, 2));
    if (downloadError case final error?) throw error;
    missing = [];
    onProgress(const AssetProgress(2, 2));
  }

  @override
  Future<Uri> resolve(String key) async => Directory.current.uri.resolve(
    'tool/assets/pack/appearance/theme-${key.split('.').last}-v1.png',
  );
}
