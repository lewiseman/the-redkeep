import 'photos/diary_photo_story_strip.dart';
import '../application/diary_media_providers.dart';
import 'daily_diary_prompt.dart';

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

class DiaryDayContent extends ConsumerStatefulWidget {
  const DiaryDayContent({
    super.key,
    required this.day,
    this.minimumHeight = 0,
    this.interactive = false,
    this.enableEntryEditing = false,
  }) : assert(minimumHeight >= 0 && minimumHeight < double.infinity);

  final DiaryPaperDay day;
  final bool interactive;

  /// Enabled by the live reader only after its header has fully collapsed.
  final bool enableEntryEditing;

  /// Centers an empty invitation while leaving the cached prose independent
  /// of the changing paper viewport.
  final double minimumHeight;

  @override
  ConsumerState<DiaryDayContent> createState() => _DiaryDayContentState();
}

class _DiaryDayContentState extends ConsumerState<DiaryDayContent> {
  Widget? _content;
  Object? _contentKey;
  bool _openingEditor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _content = null;
  }

  @override
  Widget build(BuildContext context) {
    final photoStore = ref.watch(diaryPhotoStoreProvider);
    final canEdit = ref.watch(syncCanEditProvider);
    final busy = ref.watch(diaryActionsProvider);
    final today = TimeHelper.dateOnly(ref.watch(diaryClockProvider)());
    final key = (
      widget.day,
      widget.interactive,
      widget.enableEntryEditing,
      canEdit,
      busy,
      today,
      photoStore,
    );
    if (_content == null || _contentKey != key) {
      _content = _buildContent(context, canEdit, busy, today);
      _contentKey = key;
    }
    // Sizing can change as the header collapses without rebuilding paragraphs,
    // prompts or photo widgets (and invalidating the curl's captured front).
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24,
          horizontal: math.max(24, (constraints.maxWidth - 560) / 2),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, widget.minimumHeight - 48),
          ),
          child: _content,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool canEdit,
    bool busy,
    DateTime today,
  ) {
    final day = widget.day;
    final interactive = widget.interactive;
    final canEditEntries =
        interactive && widget.enableEntryEditing && canEdit && !busy;
    final colors = diaryPaperColors(context);
    final typography = DiaryTypography.of(context);
    final details = [
      if (day.mood case final mood?) '${mood.emoji} ${mood.label}',
      ...day.themes,
    ].join(' · ');
    final canCreate =
        day.date.hasStarted(today) && (canEdit || day.date.isCurrent(today));
    Future<void> write(String? question) async {
      if (_openingEditor) return;
      _openingEditor = true;
      try {
        final id = await ref
            .read(diaryActionsProvider.notifier)
            .create(day.date);
        if (context.mounted) {
          // Held until the editor closes, so a double tap opens one editor.
          await context.push(
            diaryEntryLocation(day.date, id, edit: true),
            extra: question,
          );
        }
      } catch (_) {
        if (context.mounted) {
          diaryMessage(context, 'Could not open the editor. Retry.');
        }
      } finally {
        _openingEditor = false;
      }
    }

    final actions = canCreate
        ? Padding(
            padding: EdgeInsets.only(
              top: day.entries.isNotEmpty && day.date.isCurrent(today) ? 0 : 20,
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
                    child: DailyDiaryPrompt(
                      date: day.date,
                      onWrite: write,
                      active: interactive && day.date.isCurrent(today),
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
    final actionsAtTop = day.entries.isNotEmpty && day.date.isCurrent(today);
    return Column(
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
            if (!day.date.isDay) ...[
              Text(
                day.date.label(Localizations.localeOf(context).toString()),
                key: const ValueKey('diary-period-label'),
                style: typography.body.copyWith(
                  color: colors.secondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (day.heading.isNotEmpty || canEdit) ...[
              DiaryTitlePrompt(
                title: day.heading,
                periodName: day.date.kind.name,
                onTap: interactive && canEdit && !busy
                    ? () async {
                        if (_openingEditor) return;
                        _openingEditor = true;
                        try {
                          await context.push(diaryTitleLocation(day.date));
                        } finally {
                          _openingEditor = false;
                        }
                      }
                    : null,
              ),
              SizedBox(height: details.isEmpty ? 26 : 10),
            ],
            if (details.isNotEmpty) ...[
              Text(
                details,
                key: const ValueKey('diary-day-details'),
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: 13,
                  height: 1.4,
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
                // Static faces keep the live button's appearance. Their
                // callbacks do nothing, and the scene ignores their pointers.
                onPressed: () {
                  if (!interactive) return;
                  final listings =
                      ref.read(diaryEntriesProvider(day.date)).value ??
                      <DiaryListing>[];
                  for (final listing in listings) {
                    ref.invalidate(diaryDocumentProvider(listing.id));
                  }
                  ref.invalidate(diaryDayProvider(day.date));
                  ref.invalidate(diaryEntriesProvider(day.date));
                },
                child: const Text('Could not load this day. Retry'),
              ),
            if (actionsAtTop) actions,
            for (var i = 0; i < day.entries.length; i++) ...[
              if (i > 0) const DiaryEntryBreak(),
              Semantics(
                onLongPressHint: canEditEntries ? 'Edit entry' : null,
                child: GestureDetector(
                  key: ValueKey('diary-entry-${day.entries[i].id}'),
                  behavior: HitTestBehavior.opaque,
                  onLongPress: canEditEntries
                      ? () => context.push(
                          day.entries[i].photos.isNotEmpty
                              ? '${diaryEntryLocation(day.date, day.entries[i].id)}/photos?edit=1'
                              : diaryEntryLocation(
                                  day.date,
                                  day.entries[i].id,
                                  edit: true,
                                ),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (day.entries[i].photos.isNotEmpty)
                        DiaryPhotoStoryStrip(
                          item: day.entries[i],
                          onOpen: interactive
                              ? () => context.push(
                                  '${diaryEntryLocation(day.date, day.entries[i].id)}/photos',
                                )
                              : null,
                        ),
                      if (day.entries[i].conversation != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _DiaryConversationChip(
                            onOpen: interactive
                                ? () => context.push(
                                    '${diaryEntryLocation(day.date, day.entries[i].id)}/conversation',
                                  )
                                : null,
                          ),
                        ),
                      Text(
                        day.entries[i].text.body,
                        style: typography.body.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!actionsAtTop) actions,
        if (day.entries.isEmpty) const SizedBox.shrink(),
      ],
    );
  }
}

/// Keep the icon in the label: a chip avatar adds an animated compositing
/// layer, even at rest, which cannot be recorded into a static curl face.
class _DiaryConversationChip extends StatelessWidget {
  const _DiaryConversationChip({this.onOpen});
  final VoidCallback? onOpen;

  static void _previewTap() {}

  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onOpen ?? _previewTap,
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.forum_outlined,
          size: 18,
          color:
              ChipTheme.of(context).iconTheme?.color ?? context.colors.primary,
        ),
        const SizedBox(width: 8),
        const Flexible(child: Text('Conversation')),
      ],
    ),
  );
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
