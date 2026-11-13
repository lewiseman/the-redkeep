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
  Future<Uri> resolve(String key) async =>
      Directory.current.uri.resolve('../website/public/art/${_filename(key)}');

  String _filename(String key) => switch (key) {
    'diary.header' => 'diary_top_bg.png',
    'diary.calendar.pin' => 'diary_calendar_pin.png',
    'notes.add' => 'notes_add.png',
    'more.appearance' => 'more_appearance.png',
    'more.watchlist' => 'more_watchlist.webp',
    'flow.reflect' => 'flow_reflect.png',
    _ when key.startsWith('navigation.') && key.endsWith('.active') =>
      '${key.split('.')[1]}.png',
    _ when key.startsWith('navigation.') =>
      'navigation/${key.split('.')[1]}_${key.split('.')[2]}.png',
    'onboarding.cover' => 'cover-redkeep-castle-v1.jpg',
    'onboarding.material.paper' => 'paper-edge.webp',
    'onboarding.material.binding' => 'binding-cloth.webp',
    'onboarding.chapter.maester' => 'ai.webp',
    'onboarding.chapter.flow' => 'flow.jpg',
    'onboarding.chapter.appearance' => 'appearance.jpg',
    _ when key.startsWith('appearance.theme.') =>
      'theme_${key.split('.').last}.png',
    _ => '${key.split('.').last}.webp',
  };
}
