import 'package:redkeep/core/presentation/diary_typography.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/features/appearance/application/appearance_typography.dart';

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
