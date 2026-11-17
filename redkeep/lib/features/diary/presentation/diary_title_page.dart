import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/diary_typography.dart';
import '../application/diary_providers.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_document.dart';
import '../domain/diary_period.dart';
import 'diary_day_details_widgets.dart';
import 'diary_discard_dialog.dart';
import 'diary_widgets.dart';
import 'diary_writing_paper.dart';
import 'diary_day_page.dart';

/// The cover of a day: what to call it, how it felt and what it was about.
class DiaryTitlePage extends ConsumerStatefulWidget {
  const DiaryTitlePage({super.key, required this.date});

  final DiaryPeriod date;

  @override
  ConsumerState<DiaryTitlePage> createState() => _DiaryTitlePageState();
}

class _DiaryTitlePageState extends ConsumerState<DiaryTitlePage> {
  /// Shows the title's limit only once it's near enough to matter.
  static const _titleLimit = 160;
  static const _titleCounterFrom = 130;

  final _title = TextEditingController();
  DiaryMood? _mood;
  DiaryDay? _base;
  bool _saving = false;
  bool _leaving = false;
  bool _discarded = false;

  String get _kind => widget.date.kind.name;

  bool get _changed =>
      _base != null && (_title.text != _base!.heading || _mood != _base!.mood);

  void _pickMood(DiaryMood? mood) => setState(() {
    _mood = mood;
  });

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_base == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(diaryActionsProvider.notifier)
          .run(
            (repo) => repo.saveDay(
              DiaryDay(
                date: widget.date,
                heading: _title.text,
                mood: _mood,
                // Themes are no longer edited; any saved ones are kept.
                themes: _base!.themes,
                revision: _base!.revision,
              ),
            ),
          );
      if (mounted) await _leave();
    } catch (_) {
      if (mounted) {
        diaryMessage(
          context,
          '${_kind[0].toUpperCase()}${_kind.substring(1)} details could not be saved. Reopen the $_kind and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Returns to wherever the page was opened from.
  Future<void> _leave() async {
    setState(() => _discarded = true);
    // Let PopScope receive the cleared state.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      openDiaryDay(context, widget.date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(diaryDayProvider(widget.date));
    final busy = ref.watch(diaryActionsProvider);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving && (!_changed || _discarded),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _leaving) return;
        _leaving = true;
        final discard = await confirmDiscardDetails(context, kindName: _kind);
        if (mounted && discard) await _leave();
        _leaving = false;
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        extendBodyBehindAppBar: true,
        // The paper stays put under the keyboard; only the form shrinks.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          forceMaterialTransparency: true,
          actions: [
            DiaryPaperSaveButton(
              label: _saving ? 'Saving…' : 'Save $_kind',
              onPressed: !busy && !_saving && _changed
                  ? _save
                  : null,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: DiaryWritingBackdrop(
                variant: widget.date.weekday,
                pinned:
                    widget.date.isDay &&
                    widget.date.isCurrent(ref.read(diaryClockProvider)()),
              ),
            ),
            Positioned.fill(
              child: DiaryWritingArea(
                child: day.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('The $_kind details could not be loaded.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(diaryDayProvider(widget.date)),
                          child: const Text('Retry loading'),
                        ),
                      ],
                    ),
                  ),
                  data: (value) {
                    if (_base == null) {
                      _base = value;
                      _title.text = value.heading;
                      _mood = value.mood;
                    }
                    return _form(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = DiaryTypography.of(context);
    final editable = !_saving;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            diaryPageDate(
              widget.date,
              ref.read(diaryClockProvider)(),
              Localizations.localeOf(context).toString(),
            ),
            key: const ValueKey('diary-day-date'),
            style: typography.body.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          TextField(
            key: const ValueKey('diary-day-title-field'),
            controller: _title,
            style: typography.title.copyWith(color: colors.onSurface),
            enabled: editable,
            maxLength: _titleLimit,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => currentLength < _titleCounterFrom
                ? null
                : Text('$currentLength / $maxLength'),
            decoration: InputDecoration(
              hintText: 'Name this $_kind…',
              hintStyle: typography.title.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: .6),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 6, bottom: 2),
            ),
            onChanged: (_) => setState(() {}),
          ),
          DiaryPenLine(color: colors.onSurfaceVariant.withValues(alpha: .4)),
          const SizedBox(height: 26),
          DiaryDetailsLabel(
            text: 'How did it feel?',
            trailing: _mood == null
                ? null
                : TextButton(
                    key: const ValueKey('diary-day-mood-none'),
                    onPressed: editable ? () => _pickMood(null) : null,
                    child: const Text('Clear'),
                  ),
          ),
          const SizedBox(height: 8),
          DiaryMoodPicker(
            selected: _mood,
            onChanged: editable ? _pickMood : null,
          ),
        ],
      ),
    );
  }
}
