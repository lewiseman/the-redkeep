import '../../../core/presentation/rendering_policy.dart';

import 'dart:math' as math;

import 'package:flutter/semantics.dart';

import 'diary_style.dart';
import '../application/diary_paper_providers.dart';
import '../domain/diary_period.dart';
import 'diary_paper_material.dart';
import 'diary_sheet.dart';

/// All geometry uses the outer header's progress. The inner scrollable keeps
/// the same viewport and controller during a turn or a change of date.
class DiaryScene extends StatelessWidget {
  const DiaryScene({
    super.key,
    required this.day,
    required this.previous,
    required this.next,
    required this.today,
    required this.collapse,
    required this.headerHeight,
    this.collapseExtent = 80,
    required this.turn,
    required this.direction,
    required this.busy,
    required this.blocked,
    required this.reduced,
    required this.fade,
    required this.fadingFrom,
    required this.fadingOffset,
    required this.onCardWidth,
    required this.onDateChanged,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final DiaryPaperDay day;
  final DiaryPaperDay previous;
  final DiaryPaperDay Function() next;
  final DateTime today;
  final double collapse, headerHeight, turn, collapseExtent;
  final int direction;
  final bool busy, blocked, reduced;
  final Animation<double> fade;
  final DiaryPaperDay? fadingFrom;
  final double fadingOffset;
  final ValueChanged<double> onCardWidth;
  final ValueChanged<DiaryPeriod> onDateChanged;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragCancelCallback? onDragCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final left = (w * .123).clamp(32.0, 64.0) * (1 - collapse);
      final right = 20 * (1 - collapse);
      final gap = 12 * (1 - collapse);
      final bottom = 40 * (1 - collapse);
      final simple = RenderingPolicyScope.of(context).simplerEffects;
      final shape = DiaryPaperShape.forDate(
        day.calendarDate,
        expansion: simple ? 1 : collapse,
      );
      final rect = Rect.fromLTRB(
        left,
        headerHeight + gap,
        w - right,
        math.max(headerHeight + gap, h - bottom),
      );
      onCardWidth(rect.width);
      final previewLeft = left - rect.width - 14 - collapse * w * .35;
      final showTurn = !simple && busy && turn > 0 && !blocked && !reduced;
      final nextDay = next();
      final outgoingOffset = showTurn
          ? direction * (w + rect.width * .4) * turn
          : blocked && busy
          ? -turn * rect.width
          : 0.0;
      final paper = diaryPaperColors(context);
      final fullDate = day.date.label(
        Localizations.localeOf(context).toString(),
      );
      final restLeft = (w * .123).clamp(32.0, 64.0);
      // The nested viewport grows as its header collapses. Keep the side sheet
      // at its resting layout size and transform it to fit the current bounds.
      final restRect = Rect.fromLTRB(
        restLeft,
        headerHeight + 12,
        w - 20,
        math.max(headerHeight + 12, h - collapseExtent * collapse - 40),
      );
      final showPreview =
          !simple && collapse < 1 && previewLeft + rect.width > 0;

      Widget sideSheet(DiaryPaperDay sheet, {required bool fromLeft}) {
        final incoming = showTurn && (direction > 0) == fromLeft;
        final progress = incoming ? turn : 0.0;
        final start = fromLeft ? previewLeft : w + 14;
        final peek = fromLeft ? 1 - progress : 0.0;
        final x = start + (rect.left - start) * progress;
        final y = rect.top + 16 * peek;
        final height = math.max(0.0, rect.height - 24 * peek);
        final opacity = fromLeft
            ? (incoming ? .72 + .28 * progress : .72 * (1 - collapse))
            : 1.0;
        return Positioned.fromRect(
          key: ValueKey('diary-side-sheet-${sheet.date.key}'),
          rect: restRect,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(x - restRect.left, y - restRect.top),
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scaleX: restRect.width > 0 ? rect.width / restRect.width : 1,
                  scaleY: restRect.height > 0 ? height / restRect.height : 1,
                  child: Opacity(
                    opacity: opacity,
                    child: RepaintBoundary(
                      child: DiarySheet(
                        day: sheet,
                        showContent: incoming,
                        shadow: true,
                        minimumHeight: restRect.height,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final live = Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: rect,
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('diary-active-paper'),
                isComplex: true,
                willChange: collapse > 0 && collapse < 1,
                painter: DiaryPaperPainter(
                  shape: shape,
                  paper: paper.background,
                  ink: paper.foreground,
                  shadow: !simple,
                  shadowColor: context.colors.shadow,
                ),
              ),
            ),
          ),
          Positioned.fill(
            left: left,
            right: right,
            child: ClipPath(
              clipper: DiaryPaperClipper(
                shape,
                viewport: Rect.fromLTWH(0, rect.top, rect.width, rect.height),
              ),
              child: CustomScrollView(
                key: const PageStorageKey('diary-content'),
                physics: busy
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                slivers: [
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: gap)),
                  SliverToBoxAdapter(
                    child: DiaryDayContent(
                      key: const ValueKey('diary-live-content'),
                      interactive: true,
                      enableEntryEditing: collapse == 1 && !busy,
                      day: day,
                      minimumHeight: rect.height,
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: bottom)),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

      return Semantics(
        container: true,
        customSemanticsActions: {
          if (previous.date != day.date)
            const CustomSemanticsAction(label: 'Previous diary page'): () =>
                onDateChanged(previous.date),
          if (nextDay.date != day.date)
            const CustomSemanticsAction(label: 'Next diary page'): () =>
                onDateChanged(nextDay.date),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onHorizontalDragStart: onDragStart,
          onHorizontalDragUpdate: onDragUpdate,
          onHorizontalDragEnd: onDragEnd,
          onHorizontalDragCancel: onDragCancel,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  liveRegion: true,
                  label: 'Diary for $fullDate',
                  child: const SizedBox.shrink(),
                ),
                if (previous.date != day.date &&
                    (showPreview || (showTurn && direction > 0)))
                  sideSheet(previous, fromLeft: true),
                if (showTurn && direction < 0 && nextDay.date != day.date)
                  sideSheet(nextDay, fromLeft: false),
                ExcludeSemantics(
                  key: const ValueKey('diary-live-sheet'),
                  excluding: showTurn,
                  child: IgnorePointer(
                    ignoring: showTurn,
                    child: Transform.translate(
                      offset: Offset(outgoingOffset, 0),
                      child: FadeTransition(opacity: fade, child: live),
                    ),
                  ),
                ),
                if (fadingFrom != null && !showTurn)
                  Positioned.fromRect(
                    rect: rect,
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: FadeTransition(
                          opacity: ReverseAnimation(fade),
                          child: RepaintBoundary(
                            child: DiarySheet(
                              day: fadingFrom!,
                              shape: DiaryPaperShape.forDate(
                                fadingFrom!.calendarDate,
                                expansion: collapse,
                              ),
                              scrollOffset: fadingOffset,
                              minimumHeight: rect.height,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
