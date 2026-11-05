import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../sync/application/sync_providers.dart';
import '../application/diary_providers.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_document.dart';
import '../domain/diary_period.dart';
import 'diary_ai_sheet.dart';
import 'diary_day_details_widgets.dart';
import 'diary_discard_dialog.dart';
import 'diary_widgets.dart';
import 'diary_writing_paper.dart';

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
  final _themeDraft = TextEditingController();
  final _themeFocus = FocusNode();
  List<String> _themes = const [];
  DiaryMood? _mood;
  String? _themesError;
  DiaryDay? _base;
  bool _saving = false;
  bool _leaving = false;
  bool _discarded = false;
  int _formVersion = 0;
  final _aiSources = <String, String>{};

  String get _kind => widget.date.kind.name;

  void _manual(String field) {
    _formVersion++;
    _aiSources.remove(field);
  }

  Future<void> _ai() async {
    final version = _formVersion;
    final base = _base;
    FocusScope.of(context).unfocus();
    final accepted = await showModalBottomSheet<AcceptedDaySuggestions>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // The sheet draws its own torn paper.
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
        maxWidth: 640,
      ),
      builder: (_) => DiaryAiSheet(
        date: widget.date,
        stillCurrent: () =>
            mounted &&
            _formVersion == version &&
            _base == base &&
            ref.read(syncCanEditProvider),
      ),
    );
    // Closing the sheet hands focus back, which would raise the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted || accepted == null || version != _formVersion) return;
    setState(() {
      if (accepted.fields.contains('title')) {
        _title.text = accepted.suggestions.title!;
      }
      if (accepted.fields.contains('mood')) {
        _mood = accepted.suggestions.mood.mood;
      }
      if (accepted.fields.contains('themes')) {
        _themes = [
          for (final theme in accepted.suggestions.themes) theme.label,
        ];
        _themeDraft.clear();
        _themesError = null;
      }
      for (final field in accepted.fields) {
        _aiSources[field] = accepted.source.encode();
      }
      _formVersion++;
    });
  }

  bool get _changed =>
      _base != null &&
      (_title.text != _base!.heading ||
          _mood != _base!.mood ||
          !listEquals(_themes, _base!.themes) ||
          _themeDraft.text.trim().isNotEmpty);

  /// Adds one theme, or explains why not and leaves it for the user to fix.
  bool _addTheme(String raw) {
    if (raw.trim().isEmpty) return true;
    try {
      _themes = normalizeDiaryThemes([..._themes, raw]);
      _themesError = null;
      return true;
    } on FormatException catch (error) {
      _themesError = error.message;
      return false;
    }
  }

  void _themeTyped(String text) {
    setState(() {
      _manual('themes');
      _themesError = null;
      if (!text.contains(',')) return;
      final parts = text.split(',');
      // Everything before the last comma is finished; the rest is still typing.
      var finished = 0;
      while (finished < parts.length - 1 && _addTheme(parts[finished])) {
        finished++;
      }
      final remainder = parts.sublist(finished).join(',').trimLeft();
      _themeDraft.value = TextEditingValue(
        text: remainder,
        selection: TextSelection.collapsed(offset: remainder.length),
      );
    });
  }

  void _themeSubmitted(String text) {
    setState(() {
      _manual('themes');
      if (_addTheme(text)) _themeDraft.clear();
    });
    _themeFocus.requestFocus();
  }

  void _removeTheme(String theme) => setState(() {
    _manual('themes');
    _themes = [..._themes]..remove(theme);
    _themesError = null;
  });

  void _pickMood(DiaryMood? mood) => setState(() {
    _manual('mood');
    _mood = mood;
  });

  @override
  void dispose() {
    _title.dispose();
    _themeDraft.dispose();
    _themeFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_base == null || _saving || !ref.read(syncCanEditProvider)) return;
    // A theme still being typed is meant to be kept.
    final added = _addTheme(_themeDraft.text);
    if (!added) {
      setState(() {});
      return;
    }
    setState(_themeDraft.clear);
    final sources = _aiSources.values.toSet();
    if (sources.length > 1) {
      diaryMessage(
        context,
        'Some accepted AI fields are out of date. Edit those fields yourself or generate fresh suggestions.',
      );
      return;
    }
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
                themes: _themes,
                revision: _base!.revision,
              ),
              expectedEntries: sources.firstOrNull,
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
      context.go(diaryDayLocation(widget.date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(diaryDayProvider(widget.date));
    final canEdit = ref.watch(syncCanEditProvider);
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
              onPressed: canEdit && !busy && !_saving && _changed
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
                      _themes = value.themes;
                    }
                    return _form(context, canEdit, busy);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, bool canEdit, bool busy) {
    final colors = Theme.of(context).colorScheme;
    final typography = DiaryTypography.of(context);
    final editable = canEdit && !_saving;
    final showThemeField = _themes.length < 3 || _themeDraft.text.isNotEmpty;
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
            onChanged: (_) => setState(() => _manual('title')),
          ),
          DiaryPenLine(color: colors.onSurfaceVariant.withValues(alpha: .4)),
          if (_aiSources.containsKey('title')) const DiaryMaestarMark(),
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
          if (_aiSources.containsKey('mood')) const DiaryMaestarMark(),
          const SizedBox(height: 26),
          const DiaryDetailsLabel(text: 'What was it about?'),
          const SizedBox(height: 10),
          if (_themes.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, theme) in _themes.indexed)
                  DiaryThemeTag(
                    theme: theme,
                    index: index,
                    onRemove: editable ? () => _removeTheme(theme) : null,
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (showThemeField) ...[
            TextField(
              key: const ValueKey('diary-day-themes-field'),
              controller: _themeDraft,
              focusNode: _themeFocus,
              enabled: editable,
              style: typography.body.copyWith(height: 1.4),
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _themes.isEmpty ? 'Add a theme' : 'Add another',
                hintStyle: typography.body.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 6, bottom: 2),
              ),
              onChanged: _themeTyped,
              onSubmitted: _themeSubmitted,
            ),
            DiaryPenLine(
              color: colors.onSurfaceVariant.withValues(alpha: .35),
              stroke: 7,
            ),
          ],
          const SizedBox(height: 6),
          Semantics(
            liveRegion: _themesError != null,
            child: Text(
              _themesError ??
                  'Up to three. Press return or type a comma to add.',
              style: TextStyle(
                color: _themesError != null
                    ? colors.error
                    : colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (_aiSources.containsKey('themes')) const DiaryMaestarMark(),
          if (ref.watch(aiEnabledProvider)) ...[
            const SizedBox(height: 30),
            DiaryMaestarNote(
              kindName: _kind,
              onPressed: canEdit && !_saving && !busy ? _ai : null,
            ),
          ],
        ],
      ),
    );
  }
}
