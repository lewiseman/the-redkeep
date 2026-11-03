import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/confirm_discard_changes.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';
import '../application/diary_providers.dart';
import '../domain/civil_date.dart';
import '../domain/diary_document.dart';
import '../domain/diary_day_details.dart';
import 'diary_widgets.dart';

class DiaryTitlePage extends ConsumerStatefulWidget {
  const DiaryTitlePage({super.key, required this.date});

  final CivilDate date;

  @override
  ConsumerState<DiaryTitlePage> createState() => _DiaryTitlePageState();
}

class _DiaryTitlePageState extends ConsumerState<DiaryTitlePage> {
  final _title = TextEditingController();
  final _themes = TextEditingController();
  DiaryMood? _mood;
  String? _themesError;
  DiaryDay? _base;
  bool _saving = false;
  bool _leaving = false;
  bool _discarded = false;

  bool get _changed =>
      _base != null &&
      (_title.text != _base!.heading ||
          _mood != _base!.mood ||
          _themes.text != _base!.themes.join(', '));

  @override
  void dispose() {
    _title.dispose();
    _themes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_base == null || _saving || !ref.read(syncCanEditProvider)) return;
    List<String> themes;
    try {
      themes = normalizeDiaryThemes(_themes.text.split(','));
    } on FormatException catch (error) {
      setState(() => _themesError = error.message);
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
                themes: themes,
                revision: _base!.revision,
              ),
            ),
          );
      if (mounted) context.go(diaryDayLocation(widget.date));
    } catch (_) {
      if (mounted) {
        diaryMessage(
          context,
          'Day details could not be saved. Reopen the day and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(diaryDayProvider(widget.date));
    final canEdit = ref.watch(syncCanEditProvider);
    final busy = ref.watch(diaryActionsProvider);
    return PopScope(
      canPop: !_saving && (!_changed || _discarded),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _leaving) return;
        _leaving = true;
        final discard = await confirmDiscardChanges(context);
        if (mounted && discard) {
          setState(() => _discarded = true);
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) context.pop();
        }
        _leaving = false;
      },
      child: DiaryWritingFrame(
        title: 'Edit day',
        child: day.when(
          loading: () => const Text('Opening day details…'),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The day details could not be loaded.'),
              TextButton(
                onPressed: () => ref.invalidate(diaryDayProvider(widget.date)),
                child: const Text('Retry loading'),
              ),
            ],
          ),
          data: (value) {
            if (_base == null) {
              _base = value;
              _title.text = value.heading;
              _mood = value.mood;
              _themes.text = value.themes.join(', ');
            }
            return NotebookSurface(
              variant: widget.date.weekday,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('diary-day-title-field'),
                    controller: _title,
                    style: DiaryTypography.of(context).title,
                    enabled: canEdit && !_saving,
                    maxLength: 160,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  const Text('Mood'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('diary-day-mood-none'),
                        label: const Text('None'),
                        selected: _mood == null,
                        onSelected: canEdit && !_saving
                            ? (_) => setState(() => _mood = null)
                            : null,
                      ),
                      for (final mood in DiaryMood.values)
                        ChoiceChip(
                          key: ValueKey('diary-day-mood-${mood.name}'),
                          label: Text('${mood.emoji} ${mood.label}'),
                          selected: _mood == mood,
                          onSelected: canEdit && !_saving
                              ? (_) => setState(() => _mood = mood)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const ValueKey('diary-day-themes-field'),
                    controller: _themes,
                    enabled: canEdit && !_saving,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Themes',
                      helperText: 'Up to three, separated by commas. 40 characters each.',
                      helperMaxLines: 4,
                      errorText: _themesError,
                      errorMaxLines: 4,
                    ),
                    onChanged: (_) => setState(() => _themesError = null),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: canEdit && !busy && !_saving && _changed
                        ? _save
                        : null,
                    child: Text(_saving ? 'Saving…' : 'Save day'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
