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
import 'diary_widgets.dart';

class DiaryTitlePage extends ConsumerStatefulWidget {
  const DiaryTitlePage({super.key, required this.date});

  final CivilDate date;

  @override
  ConsumerState<DiaryTitlePage> createState() => _DiaryTitlePageState();
}

class _DiaryTitlePageState extends ConsumerState<DiaryTitlePage> {
  final _title = TextEditingController();
  DiaryDay? _base;
  bool _saving = false;
  bool _leaving = false;
  bool _discarded = false;

  bool get _changed => _base != null && _title.text != _base!.heading;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_base == null || _saving || !ref.read(syncCanEditProvider)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(diaryActionsProvider.notifier)
          .run((repo) => repo.renameDay(_base!, _title.text));
      if (mounted) context.go(diaryDayLocation(widget.date));
    } catch (_) {
      if (mounted) {
        diaryMessage(
          context,
          'Title could not be saved. Reopen the day and retry.',
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
        title: 'Edit day title',
        child: day.when(
          loading: () => const Text('Opening title…'),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The day title could not be loaded.'),
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
                  FilledButton(
                    onPressed: canEdit && !busy && !_saving && _changed
                        ? _save
                        : null,
                    child: Text(_saving ? 'Saving…' : 'Save title'),
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
