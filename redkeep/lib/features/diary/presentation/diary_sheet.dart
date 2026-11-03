import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';
import '../application/diary_paper_providers.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_style.dart';
import 'diary_paper_material.dart';
import 'diary_paper_stamp.dart';
import 'diary_writing_prompt.dart';
import 'diary_widgets.dart';

DiaryPaperColors diaryPaperColors(BuildContext context) => DiaryPaperColors(
  background: context.colors.surface,
  foreground: context.colors.onSurface,
  secondary: context.colors.onSurfaceVariant,
);

/// The static face used for previews and curls has no scrollable or layers.
/// Its clipped overflow is exactly the beginning of the live reading view.
class DiarySheet extends StatelessWidget {
  const DiarySheet({
    super.key,
    required this.day,
    this.radius = 6,
    this.scrollOffset = 0,
    this.shape,
    this.shadow = false,
    this.detailed = true,
    this.minimumHeight = 0,
  });

  final DiaryPaperDay day;
  final double radius;
  final double scrollOffset;
  final DiaryPaperShape? shape;
  final bool shadow;
  final bool detailed;

  // Use the fixed face bounds without a layout callback during page turns.
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final outline =
        shape ??
        DiaryPaperShape.forDate(day.calendarDate, cornerRadius: radius);
    final paper = diaryPaperColors(context);
    final content = OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Transform.translate(
        offset: Offset(0, -scrollOffset),
        child: DiaryDayContent(day: day, minimumHeight: minimumHeight),
      ),
    );
    return CustomPaint(
      painter: detailed
          ? DiaryPaperPainter(
              shape: outline,
              paper: paper.background,
              ink: paper.foreground,
              shadow: shadow,
              shadowColor: context.colors.shadow,
            )
          : DiaryPaperStamp(
              paper: paper.background,
              ink: paper.foreground,
              shadow: shadow,
              shadowColor: context.colors.shadow,
              variant: day.calendarDate.weekday,
              flatten: outline.expansion,
            ),
      child: detailed
          ? ClipPath(clipper: DiaryPaperClipper(outline), child: content)
          : ClipRect(
              clipper: _StampContentClipper(outline.detail),
              child: content,
            ),
    );
  }
}

class _StampContentClipper extends CustomClipper<Rect> {
  const _StampContentClipper(this.detail);
  final double detail;

  @override
  Rect getClip(Size size) => (Offset.zero & size).deflate(8 * detail);

  @override
  bool shouldReclip(_StampContentClipper oldClipper) =>
      detail != oldClipper.detail;
}

class DiaryDayContent extends ConsumerWidget {
  const DiaryDayContent({
    super.key,
    required this.day,
    this.minimumHeight = 0,
    this.interactive = false,
  }) : assert(minimumHeight >= 0 && minimumHeight < double.infinity);

  final DiaryPaperDay day;
  final bool interactive;

  /// Centers an empty invitation while leaving the cached prose independent
  /// of the changing paper viewport.
  final double minimumHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = diaryPaperColors(context);
    final typography = DiaryTypography.of(context);
    final canEdit = ref.watch(syncCanEditProvider);
    final busy = ref.watch(diaryActionsProvider);
    final today = TimeHelper.dateOnly(ref.read(diaryClockProvider)());
    final canCreate =
        !day.calendarDate.isAfter(today) &&
        (canEdit || day.calendarDate == today);
    Future<void> write() async {
      try {
        final id = await ref
            .read(diaryActionsProvider.notifier)
            .create(day.date);
        if (context.mounted) {
          context.go(diaryEntryLocation(day.date, id, edit: true));
        }
      } catch (_) {
        if (context.mounted) {
          diaryMessage(context, 'Could not open the editor. Retry.');
        }
      }
    }

    final actions = canCreate
        ? Padding(
            padding: EdgeInsets.only(
              top: day.entries.isNotEmpty && day.calendarDate == today ? 0 : 20,
              bottom: day.entries.isEmpty ? 20 : 26,
            ),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AbsorbPointer(
                    absorbing: busy || !interactive,
                    child: DiaryWritingPrompt(onTap: write),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
    final actionsAtTop = day.entries.isNotEmpty && day.calendarDate == today;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: day.entries.isEmpty
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (day.heading.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(right: 32),
                child: Text(
                  day.heading,
                  style: typography.title.copyWith(color: colors.foreground),
                ),
              ),
              const SizedBox(height: 26),
            ],
            if (day.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Loading entries…'),
              ),
            if (day.failed)
              TextButton(
                onPressed: interactive
                    ? () {
                        final listings =
                            ref.read(diaryEntriesProvider(day.date)).value ??
                            <DiaryListing>[];
                        for (final listing in listings) {
                          ref.invalidate(diaryDocumentProvider(listing.id));
                        }
                        ref.invalidate(diaryDayProvider(day.date));
                        ref.invalidate(diaryEntriesProvider(day.date));
                      }
                    : null,
                child: const Text('Could not load this day. Retry'),
              ),
            if (actionsAtTop) actions,
            for (var i = 0; i < day.entries.length; i++) ...[
              if (i > 0) const DiaryEntryBreak(),
              if (day.entries[i].text.title.isNotEmpty) ...[
                Text(
                  day.entries[i].text.title,
                  style: typography.title.copyWith(color: colors.foreground),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                day.entries[i].text.body,
                style: typography.body.copyWith(color: colors.foreground),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: interactive
                      ? () => context.go(
                          diaryEntryLocation(day.date, day.entries[i].id),
                        )
                      : null,
                  child: const Text('Read full entry'),
                ),
              ),
            ],
          ],
        ),
        if (!actionsAtTop) actions,
        if (day.entries.isEmpty) const SizedBox.shrink(),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24,
          horizontal: math.max(24, (constraints.maxWidth - 560) / 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, minimumHeight - 48),
              ),
              child: content,
            ),
            if (canEdit)
              Positioned(
                top: -12,
                right: -16,
                child: IconButton(
                  tooltip: 'Name this day',
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: colors.secondary,
                  ),
                  onPressed: !interactive || busy
                      ? null
                      : () => renameDiaryDay(context, ref, day),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> renameDiaryDay(
  BuildContext context,
  WidgetRef ref,
  DiaryPaperDay paper,
) async {
  final day = ref.read(diaryDayProvider(paper.date)).value;
  if (day == null) return;
  final controller = TextEditingController(text: day.heading);
  final heading = await showDialog<String>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
    builder: (context) => DiaryDialog(
      children: [
        Text('Name this day', style: Theme.of(context).textTheme.headlineSmall),
        TextField(
          controller: controller,
          style: DiaryTypography.of(context).title,
          maxLength: 160,
          maxLines: null,
          decoration: const InputDecoration(labelText: 'Day heading'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save heading'),
        ),
      ],
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  if (heading == null) return;
  try {
    await ref
        .read(diaryActionsProvider.notifier)
        .run((repo) => repo.renameDay(day, heading));
  } catch (_) {
    if (context.mounted) {
      diaryMessage(
        context,
        'Heading could not be saved. Reload the day and retry.',
      );
    }
  }
}

/// A brief pencil mark between entries, rather than another container.
class DiaryEntryBreak extends StatelessWidget {
  const DiaryEntryBreak({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 23),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: CustomPaint(
        size: const Size(24, 3),
        painter: _NotebookMark(
          ink: context.colors.onSurfaceVariant,
          dash: true,
        ),
      ),
    ),
  );
}

class _NotebookMark extends CustomPainter {
  const _NotebookMark({required this.ink, this.dash = false});
  final Color ink;
  final bool dash;
  static final _dash = Path()
    ..moveTo(0, 1.8)
    ..quadraticBezierTo(12, .5, 23, 1.5);
  static final _quotes = Path()
    ..moveTo(2, 2)
    ..quadraticBezierTo(0, 5, 1, 7)
    ..moveTo(7, 1)
    ..quadraticBezierTo(5, 4, 6, 6);

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    dash ? _dash : _quotes,
    Paint()
      ..color = ink.withValues(alpha: dash ? .35 : .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85
      ..strokeCap = StrokeCap.round,
  );

  @override
  bool shouldRepaint(_NotebookMark oldDelegate) =>
      ink != oldDelegate.ink || dash != oldDelegate.dash;
}
