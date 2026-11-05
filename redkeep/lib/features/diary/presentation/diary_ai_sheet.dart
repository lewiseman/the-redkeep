import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../application/diary_ai_sources.dart';
import '../domain/diary_period.dart';
import '../domain/diary_ai_contract.dart';

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
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(
      () => unawaited(ref.read(aiJobsProvider.notifier).restore()),
    );
  }

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
          .read(aiJobsProvider.notifier)
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
      await ref.read(aiJobsProvider.notifier).clear();
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
    final state = ref.watch(aiJobsProvider);
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
    Widget review(
      String field,
      String label,
      String value, {
      String? evidence,
    }) => CheckboxListTile(
      key: ValueKey('diary-ai-$field'),
      contentPadding: EdgeInsets.zero,
      value: _fields.contains(field),
      onChanged: busy
          ? null
          : (v) => setState(() {
              v == true ? _fields.add(field) : _fields.remove(field);
            }),
      title: Text('$label: $value'),
      subtitle: evidence == null ? null : Text('“$evidence”'),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.date.kind.name[0].toUpperCase()}${widget.date.kind.name.substring(1)} details with AI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Uses only this ${widget.date.kind.name}’s saved entry text. Review each suggestion, then apply the fields you want. Save ${widget.date.kind.name} commits them.',
            ),
            const SizedBox(height: 12),
            if (task != null)
              Text(
                ours
                    ? 'AI task: ${task.phase}'
                    : 'Another AI task is waiting. Finish or clear it before generating ${widget.date.kind.name} details.',
              ),
            if (_message ?? state.message case final message?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(message, key: const ValueKey('diary-ai-message')),
              ),
            if (suggestions != null) ...[
              if (suggestions.title case final title?)
                review('title', 'Title', title)
              else
                Text(
                  suggestions.rejectedFields.contains('title')
                      ? 'Title: The suggestion could not be matched to this ${widget.date.kind.name}’s writing.'
                      : 'Title: No title was suggested.',
                  key: const ValueKey('diary-ai-no-title'),
                ),
              if (suggestions.mood.mood case final mood?)
                review(
                  'mood',
                  'Mood',
                  '${mood.emoji} ${mood.label}',
                  evidence: suggestions.mood.evidence,
                )
              else
                Text(
                  suggestions.mood.value == 'mixed'
                      ? 'Mixed feelings: no single mood suggested.'
                      : 'No mood suggested.',
                ),
              if (suggestions.themes.isNotEmpty)
                review(
                  'themes',
                  'Themes',
                  suggestions.themes.map((t) => t.label).join(', '),
                  evidence: suggestions.themes
                      .map((t) => t.evidence)
                      .join(' · '),
                )
              else
                Text(
                  suggestions.rejectedFields.contains('themes')
                      ? 'Themes: The suggestions could not be matched to this ${widget.date.kind.name}’s writing.'
                      : 'Themes: No themes were suggested.',
                  key: const ValueKey('diary-ai-no-themes'),
                ),
              if (suggestions.dropped > 0)
                Text(
                  '${suggestions.dropped} suggestion${suggestions.dropped == 1 ? ' was' : 's were'} left out after checking against your saved writing.',
                ),
              if (suggestions.empty)
                const Text(
                  'There was not enough in the entries for a grounded suggestion. You can edit details yourself.',
                ),
              FilledButton(
                key: const ValueKey('diary-ai-apply'),
                onPressed: busy || _fields.isEmpty
                    ? null
                    : () => _apply(source!, suggestions!),
                child: const Text('Apply selected fields'),
              ),
            ],
            if (task == null)
              FilledButton(
                key: const ValueKey('diary-ai-generate'),
                onPressed: busy ? null : _generate,
                child: Text(busy ? 'Thinking…' : 'Generate suggestions'),
              ),
            if (task != null)
              Wrap(
                spacing: 8,
                children: [
                  if (!task.terminal)
                    TextButton(
                      onPressed: _checking
                          ? null
                          : ref.read(aiJobsProvider.notifier).cancel,
                      child: const Text('Cancel task'),
                    ),
                  if (!state.busy)
                    TextButton(
                      onPressed: _checking
                          ? null
                          : task.terminal
                          ? () async {
                              await ref.read(aiJobsProvider.notifier).clear();
                              if (mounted) await _generate();
                            }
                          : ref.read(aiJobsProvider.notifier).retry,
                      child: Text(
                        task.terminal ? 'Generate again' : 'Retry task',
                      ),
                    ),
                  if (task.terminal)
                    TextButton(
                      onPressed: busy
                          ? null
                          : ref.read(aiJobsProvider.notifier).clear,
                      child: const Text('Clear task'),
                    ),
                ],
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/settings/brain');
              },
              child: const Text('Grand Maestar settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
