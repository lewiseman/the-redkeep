import 'package:redkeep/core/presentation/diary_typography.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/features/appearance/application/appearance_typography.dart';
import 'package:redkeep/features/appearance/data/font_preview_loader.dart';

Future<ResolvedFont> fakeAppearanceFontLoader(
  String family,
  FontRole role,
) async => role == FontRole.journal
    ? ResolvedFont(
        textTheme: RedkeepTheme.light.textTheme.apply(fontFamily: family),
      )
    : ResolvedFont(
        style:
            (role == FontRole.diaryTitle
                    ? const DiaryTypography().title
                    : const DiaryTypography().body)
                .copyWith(fontFamily: family),
      );

/// Never touches the network or disk; records what the picker asked for.
class FakeFontPreviewLoader implements FontPreviewLoader {
  final requested = <String>[];
  final cancelled = <String>[];
  final ready = <String, String>{};

  @override
  int get maxConcurrent => 4;

  @override
  String? readyFamily(String family) => ready[family];

  @override
  Future<String?> load(String family) async {
    requested.add(family);
    return ready[family];
  }

  @override
  void cancel(String family) => cancelled.add(family);

  @override
  void dispose() {}
}
