import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/media_motion.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../application/diary_ai_sources.dart';
import '../domain/diary_period.dart';
import '../domain/diary_ai_contract.dart';
import 'diary_day_details_widgets.dart';
import 'diary_paper_stamp.dart';
import 'diary_writing_paper.dart';
import 'photos/diary_ink_action.dart';

class AcceptedDaySuggestions {
  const AcceptedDaySuggestions(this.source, this.suggestions, this.fields);
  final DiarySuggestionSource source;
  final DiarySuggestions suggestions;
  final Set<String> fields;
}

class DiaryAiSheet extends ConsumerStatefulWidget {
  const DiaryAiSheet({
    super.key,
    required this.date,
    required this.stillCurrent,
  });
  final DiaryPeriod date;
  final bool Function() stillCurrent;
  @override
  ConsumerState<DiaryAiSheet> createState() => _DiaryAiSheetState();
}

class _DiaryAiSheetState extends ConsumerState<DiaryAiSheet> {
  final _fields = <String>{};
  String? _reviewed, _message;
  bool _checking = false;

  /// This sheet's request. Closing the sheet cancels it.
  AiJobsProvider get _jobs =>
      aiJobsProvider('diary-details:${widget.date.key}');

  Future<void> _generate() async {
    setState(() {
      _message = null;
      _checking = true;
    });
    try {
      final source = await ref.read(diaryAiSourcesProvider).day(widget.date);
      final prompt = source.request();
      if (!mounted || !widget.stillCurrent()) return;
      await ref
          .read(_jobs.notifier)
          .start(
            AiOperation.diaryDetails,
            widget.date.key,
            prompt,
            source.encode(),
          );
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not read this ${widget.date.kind.name}. Your details are unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _apply(
    DiarySuggestionSource source,
    DiarySuggestions suggestions,
  ) async {
    setState(() => _checking = true);
    try {
      if (!widget.stillCurrent() ||
          !await ref.read(diaryAiSourcesProvider).current(source)) {
        if (mounted) {
          setState(
            () => _message = 'This day changed. These suggestions are out of date; ask again.',
          );
        }
        return;
      }
      if (!mounted) return;
      final result = AcceptedDaySuggestions(
        source,
        suggestions,
        Set.of(_fields),
      );
      await ref.read(_jobs.notifier).clear();
      if (mounted && widget.stillCurrent()) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not apply suggestions. Your details are unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_jobs);
    final task = state.job;
    final ours =
        task?.operation == AiOperation.diaryDetails &&
        task?.key == widget.date.key;
    DiarySuggestionSource? source;
    DiarySuggestions? suggestions;
    if (ours && task!.phase == 'completed' && task.text != null) {
      try {
        source = DiarySuggestionSource.decode(task.source);
        suggestions = DiarySuggestions.parse(task.text!, source);
      } on FormatException {
        _message = 'The result did not pass its checks. Ask again.';
      }
      if (_reviewed != task.id) {
        _fields.clear();
        _reviewed = task.id;
      }
    }
    final busy = state.busy || _checking;
    final kind = widget.date.kind.name;
    final colors = Theme.of(context).colorScheme;
    final reading = ours && !task!.terminal;
    final (heading, intro) = switch ((task, suggestions)) {
      (_, _?) => (
        "Here's what I found",
        'Tick what you’d like to keep. Nothing is stored until you save this $kind.',
      ),
      (null, _) => (
        'Shall I read this $kind?',
        'I’ll use only this $kind’s saved entries to suggest a title, mood and themes. You choose what to keep, and nothing is stored until you save this $kind.',
      ),
      _ when !ours => (
        'I’m busy with something else',
        'Another AI task is waiting. Finish or clear it before generating $kind details.',
      ),
      _ when reading => (
        'Reading this $kind…',
        task.phase == 'running'
            ? 'Going through your saved entries now. You can leave this open.'
            : 'Getting ready to read your saved entries.',
      ),
      _ => ('I couldn’t finish', _endedText(task!.phase, kind)),
    };
    Widget review(
      String field,
      String label,
      String value, {
      String? evidence,
      bool handwritten = false,
    }) => _SuggestionRow(
      key: ValueKey('diary-ai-$field'),
      label: label,
      value: value,
      evidence: evidence,
      handwritten: handwritten,
      selected: _fields.contains(field),
      onPressed: busy
          ? null
          : () => setState(() {
              _fields.contains(field)
                  ? _fields.remove(field)
                  : _fields.add(field);
            }),
    );
    final note = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13,
      height: 1.4,
    );
    return _TornPage(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Image.asset(
                    diaryMaestarAsset,
                    key: const ValueKey('diary-ai-maestar'),
                    width: _TornPage.portrait,
                    height: _TornPage.portrait,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                    cacheWidth:
                        (_TornPage.portrait *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        heading,
                        style: DiaryTypography.of(context).title.copyWith(
                          color: colors.onSurface,
                          fontSize: 28,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(intro, style: note.copyWith(fontSize: 14)),
              if (reading && !mediaMotionDisabled(context)) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_message ?? state.message case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      key: const ValueKey('diary-ai-message'),
                      style: note.copyWith(color: colors.error),
                    ),
                  ),
                ),
              if (suggestions != null) ...[
                const SizedBox(height: 10),
                if (suggestions.title case final title?)
                  review('title', 'Title', title, handwritten: true)
                else
                  _Omitted(
                    suggestions.rejectedFields.contains('title')
                        ? 'Title: The suggestion could not be matched to this $kind’s writing.'
                        : 'Title: No title was suggested.',
                    key: const ValueKey('diary-ai-no-title'),
                  ),
                if (suggestions.mood.mood case final mood?)
                  review(
                    'mood',
                    'Mood',
                    mood.display,
                    evidence: suggestions.mood.evidence,
                  )
                else
                  _Omitted(
                    suggestions.mood.value == 'mixed'
                        ? 'Mixed feelings: no single mood suggested.'
                        : 'No mood suggested.',
                  ),
                if (suggestions.themes.isNotEmpty)
                  review(
                    'themes',
                    'Themes',
                    suggestions.themes.map((t) => t.label).join(' · '),
                    evidence: suggestions.themes
                        .map((t) => t.evidence)
                        .join(' · '),
                  )
                else
                  _Omitted(
                    suggestions.rejectedFields.contains('themes')
                        ? 'Themes: The suggestions could not be matched to this $kind’s writing.'
                        : 'Themes: No themes were suggested.',
                    key: const ValueKey('diary-ai-no-themes'),
                  ),
                if (suggestions.dropped > 0)
                  _Omitted(
                    '${suggestions.dropped} suggestion${suggestions.dropped == 1 ? ' was' : 's were'} left out after checking against your saved writing.',
                  ),
                if (suggestions.empty)
                  const _Omitted(
                    'There was not enough in the entries for a grounded suggestion. You can edit details yourself.',
                  ),
                const SizedBox(height: 14),
                DiaryInkSlip(
                  key: const ValueKey('diary-ai-apply'),
                  label: _fields.isEmpty
                      ? 'Tick what to keep'
                      : 'Use what I ticked',
                  onPressed: busy || _fields.isEmpty
                      ? null
                      : () => _apply(source!, suggestions!),
                ),
              ],
              if (task == null) ...[
                const SizedBox(height: 18),
                DiaryInkSlip(
                  key: const ValueKey('diary-ai-generate'),
                  label: busy ? 'Thinking…' : 'Read this $kind',
                  onPressed: busy ? null : _generate,
                ),
              ],
              const SizedBox(height: 8),
              // Everything else stays quiet, and wraps at large text.
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (task != null) ...[
                    if (!task.terminal)
                      _QuietAction(
                        'Stop reading',
                        _checking ? null : ref.read(_jobs.notifier).cancel,
                      ),
                    if (!state.busy)
                      _QuietAction(
                        task.terminal ? 'Generate again' : 'Try again',
                        _checking
                            ? null
                            : task.terminal
                            ? () async {
                                await ref.read(_jobs.notifier).clear();
                                if (mounted) await _generate();
                              }
                            : ref.read(_jobs.notifier).retry,
                      ),
                    if (task.terminal)
                      _QuietAction(
                        'Clear task',
                        busy ? null : ref.read(_jobs.notifier).clear,
                      ),
                  ],
                  _QuietAction('Grand Maestar settings', () {
                    Navigator.pop(context);
                    context.push('/settings/brain');
                  }),
                  _QuietAction('Close', () => Navigator.pop(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Why a task ended without suggestions, in plain words.
  String _endedText(String phase, String kind) => switch (phase) {
    'cancelled' =>
      'You stopped me before I finished. Your details are unchanged.',
    'expired' =>
      'That took too long, so I stopped. Your details are unchanged.',
    'interrupted' => 'Something interrupted me while I was reading. Your details are unchanged.',
    'completed' => 'My answer didn’t pass its checks against your writing. Your details are unchanged.',
    _ =>
      'Something went wrong while I read this $kind. Your details are unchanged.',
  };
}

/// A page torn from the diary. Only its top edge shows, with room above for the
/// Grand Maestar to sit on it.
class _TornPage extends StatelessWidget {
  const _TornPage({required this.child});

  static const portrait = 76.0;
  static const _perch = 34.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          top: _perch,
          left: -14,
          right: -14,
          bottom: -24,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: DiaryPaperStamp(
                paper: simple ? colors.surfaceContainerLow : colors.surface,
                ink: colors.onSurface,
                shadowColor: colors.shadow,
                variant: 2,
                edgeScale: simple ? 0 : .8,
                shadow: !simple,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A suggestion to tick, with the words from the entries that support it.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    super.key,
    required this.label,
    required this.value,
    required this.evidence,
    required this.handwritten,
    required this.selected,
    required this.onPressed,
  });

  final String label, value;
  final String? evidence;
  final bool handwritten, selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = DiaryTypography.of(context);
    return DiaryInkAction(
      label:
          '$label: $value${evidence == null ? '' : '. From your writing: $evidence'}',
      selected: selected,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox.square(
                dimension: 24,
                child: CustomPaint(
                  painter: _InkTick(
                    box: colors.onSurfaceVariant.withValues(alpha: .6),
                    tick: colors.primary,
                    ticked: selected,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style:
                        (handwritten
                                ? typography.title.copyWith(
                                    fontSize: 26,
                                    height: 1.15,
                                  )
                                : typography.body.copyWith(
                                    fontSize: 16,
                                    height: 1.4,
                                  ))
                            .copyWith(color: colors.onSurface),
                  ),
                  if (evidence case final words?) ...[
                    const SizedBox(height: 4),
                    Text(
                      '“$words”',
                      style: typography.body.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A box drawn by hand, and a tick that overshoots it.
class _InkTick extends CustomPainter {
  const _InkTick({required this.box, required this.tick, required this.ticked});

  final Color box, tick;
  final bool ticked;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.drawPath(
      Path()
        ..moveTo(s * .14, s * .2)
        ..quadraticBezierTo(s * .5, s * .15, s * .82, s * .18)
        ..quadraticBezierTo(s * .86, s * .5, s * .83, s * .84)
        ..quadraticBezierTo(s * .5, s * .88, s * .15, s * .85)
        ..quadraticBezierTo(s * .11, s * .5, s * .14, s * .2)
        ..close(),
      Paint()
        ..color = box
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    if (!ticked) return;
    canvas.drawPath(
      Path()
        ..moveTo(s * .27, s * .5)
        ..quadraticBezierTo(s * .36, s * .6, s * .43, s * .72)
        ..quadraticBezierTo(s * .62, s * .36, s * .96, s * .02),
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_InkTick oldDelegate) =>
      box != oldDelegate.box ||
      tick != oldDelegate.tick ||
      ticked != oldDelegate.ticked;
}

/// Says why a field has nothing to tick, rather than letting it vanish.
class _Omitted extends StatelessWidget {
  const _Omitted(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
        height: 1.4,
      ),
    ),
  );
}

class _QuietAction extends StatelessWidget {
  const _QuietAction(this.label, this.onPressed);

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      textStyle: const TextStyle(fontSize: 13),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}
