import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_day_details.dart';

/// Opens a full emoji picker; resolves to the chosen mood, or null when the
/// sheet is dismissed.
Future<DiaryMood?> showDiaryEmojiPicker(BuildContext context) =>
    showModalBottomSheet<DiaryMood>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: math.min(MediaQuery.sizeOf(context).height * .75, 560),
        maxWidth: 640,
      ),
      builder: (_) => const DiaryEmojiPickerSheet(),
    );

/// Every emoji, with search and skin tones. Recently used emoji are not kept:
/// a day's mood is stored only with the day.
class DiaryEmojiPickerSheet extends StatelessWidget {
  const DiaryEmojiPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final policy = RenderingPolicyScope.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Bigger text gets bigger, fewer emoji per row; 320px still fits six.
        final columns = (constraints.maxWidth / (40 * scale)).floor().clamp(
          5,
          10,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Pick any emoji',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EmojiPicker(
                key: const ValueKey('diary-emoji-picker'),
                onEmojiSelected: (_, emoji) {
                  final mood = DiaryMood.fromEmoji(emoji.emoji);
                  if (mood != null) Navigator.of(context).pop(mood);
                },
                config: Config(
                  height: null,
                  categoryViewConfig: CategoryViewConfig(
                    recentTabBehavior: RecentTabBehavior.NONE,
                    initCategory: Category.SMILEYS,
                    tabIndicatorAnimDuration: policy.duration,
                    backgroundColor: colors.surfaceContainerLow,
                    indicatorColor: colors.primary,
                    iconColor: colors.onSurfaceVariant,
                    iconColorSelected: colors.primary,
                    backspaceColor: colors.primary,
                    dividerColor: colors.outlineVariant,
                  ),
                  emojiViewConfig: EmojiViewConfig(
                    columns: columns,
                    emojiSizeMax: 28 * scale,
                    backgroundColor: colors.surface,
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                  skinToneConfig: SkinToneConfig(
                    dialogBackgroundColor: colors.surfaceContainerHigh,
                    indicatorColor: colors.onSurfaceVariant,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    showBackspaceButton: false,
                    backgroundColor: colors.surfaceContainerLow,
                    buttonColor: colors.surfaceContainerLow,
                    buttonIconColor: colors.onSurfaceVariant,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: colors.surfaceContainerLow,
                    buttonIconColor: colors.onSurfaceVariant,
                    hintText: 'Search emoji',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
