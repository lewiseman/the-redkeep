import '../../../core/presentation/media_motion.dart';
import '../data/voice_store.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../diary/application/diary_providers.dart';
import '../../diary/domain/diary_document.dart';
import '../../sync/application/sync_providers.dart';
import '../domain/voice_session.dart';
import '../application/diary_conversation_draft.dart';
import '../application/voice_coordination.dart';
import 'widgets/voice_session_chrome.dart';
import 'widgets/voice_transcript.dart';

class DiaryConversationPage extends ConsumerStatefulWidget {
  const DiaryConversationPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  ConsumerState<DiaryConversationPage> createState() =>
      _DiaryConversationPageState();
}

class _DiaryConversationPageState extends ConsumerState<DiaryConversationPage> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  DiaryEntry? _source;
  bool _busy = false;
  String? _message;
  int? _expectedRevision;
  late final VoiceStore _store;
  String get _target => 'diary-review-${widget.address.id}';
  @override
  void initState() {
    super.initState();
    _store = ref.read(voiceStoreProvider);
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    try {
      final entry =
          (await ref
                  .read(diaryRepositoryProvider)
                  .openDocument(widget.address.id))
              .entry;
      final retained = await _store.load(_target);
      if (!mounted || entry?.conversation == null) return;
      var expectedRevision = retained?['revision'] as int? ?? entry!.revision;
      var stale = false;
      if (retained?['source'] case final Map<String, dynamic> source) {
        try {
          expectedRevision = conversationDraftRevision(entry!, source);
        } on StateError {
          stale = true;
        }
      }
      setState(() {
        _source = entry;
        _expectedRevision = expectedRevision;
        _draft.text = retained?['draft'] as String? ?? entry!.text.body;
        if (stale || _expectedRevision != entry!.revision) _message = 'The entry changed after this draft. Your draft is kept; reopen the current entry before replacing it.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not open the saved draft. Your entry is unchanged.',
        );
      }
    }
  }

  Future<void> _retainDraft() async {
    if (_source == null) return;
    await _store.save(_target, {
      'id': widget.address.id,
      'created': DateTime.now().millisecondsSinceEpoch,
      'revision': _expectedRevision,
      'draft': _draft.text,
    });
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      ) ==
      true;
  Future<void> _generate(DiaryEntry entry) async {
    if (_draft.text.trim().isNotEmpty &&
        !await _confirm(
          'Write a new draft?',
          'This replaces the draft you are editing.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final jobs = ref.read(aiJobsProvider.notifier);
      await jobs.restore();
      var job = ref.read(aiJobsProvider).job;
      if (job != null &&
          (job.operation != AiOperation.conversation || job.key != entry.id)) {
        throw StateError('Another AI task is waiting in Grand Maestar.');
      }
      if (job != null && job.terminal && job.phase != 'completed') {
        await jobs.clear();
        job = null;
      }
      if (job == null) {
        await jobs.start(
          AiOperation.conversation,
          entry.id,
          jsonEncode({'action': 'draft', 'turns': entry.conversation!.turns}),
          jsonEncode({
            'id': entry.id,
            'date': entry.date.key,
            'revision': entry.revision,
            'turns': entry.conversation!.turns,
          }),
        );
      } else if (!job.terminal) {
        await jobs.retry();
      }
      job = ref.read(aiJobsProvider).job;
      if (job?.phase != 'completed' || job?.text == null) {
        throw StateError(
          ref.read(aiJobsProvider).message ?? 'Your conversation is kept. Try again when your computer is ready.',
        );
      }
      if (!mounted) return;
      _source = entry;
      _expectedRevision = conversationDraftRevision(
        entry,
        jsonDecode(job!.source) as Map<String, dynamic>,
      );
      _draft.text = job.text!;
      await _retainDraft();
      await jobs.clear();
    } catch (e) {
      if (mounted) {
        _message = e is StateError
            ? e.message.toString()
            : 'Could not write a draft. Your conversation is kept.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update() async {
    final source = _source;
    if (source == null || _draft.text.trim().isEmpty) return;
    if (source.text.body.isNotEmpty &&
        source.text.body != _draft.text.trim() &&
        !await _confirm(
          'Replace this entry’s words?',
          'The entry will read as this draft.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(diaryRepositoryProvider)
          .saveConversation(
            id: source.id,
            date: source.date,
            conversation: source.conversation!.copyWith(
              draftedAt: DateTime.now(),
            ),
            expectedRevision: _expectedRevision ?? source.revision,
            body: _draft.text.trim(),
          );
      await _store.clear(_target);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'This entry changed or could not be saved. Your draft is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = ref.watch(diaryDocumentProvider(widget.address.id));
    final entry = document.value?.entry;
    final record = entry?.conversation ?? _source?.conversation;
    final writable =
        ref.watch(syncCanEditProvider) &&
        document.value?.available == true &&
        entry?.date == widget.address.date;
    final ink = VoiceColors.of(context).ink;
    return Scaffold(
      backgroundColor: VoiceColors.of(context).paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              controller: _scroll,
              children: [
                VoiceSessionHeader(
                  title: 'Your conversation',
                  subtitle: widget.address.date.key,
                  onClose: () => Navigator.pop(context),
                ),
                if (record == null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      document.isLoading
                          ? 'Opening conversation…'
                          : 'This conversation is no longer in your diary.',
                    ),
                  )
                else
                  VoiceTranscript(
                    embedded: true,
                    scrollController: _scroll,
                    turns: [
                      for (final t in record.turns)
                        VoiceTranscriptTurn(
                          speaker: t['speaker'] == 'user'
                              ? VoiceSpeaker.user
                              : VoiceSpeaker.assistant,
                          text: t['text']!,
                        ),
                    ],
                    mode: VoiceSessionMode.conversation,
                    ink: ink,
                    reducedMotion: mediaMotionDisabled(context),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_message!),
                  ),
                if (record != null && _source != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      key: const ValueKey('conversation-draft'),
                      controller: _draft,
                      enabled: !_busy,
                      readOnly: !writable,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Draft',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        unawaited(_retainDraft().catchError((_) {}));
                      },
                    ),
                  ),
                VoiceSessionControls(
                  actionLabel: _draft.text.isNotEmpty
                      ? 'Write a new draft'
                      : null,
                  actionIcon: _draft.text.isNotEmpty
                      ? Icons.refresh_rounded
                      : null,
                  onAction: _busy || !writable || entry == null
                      ? null
                      : () => _generate(entry),
                  primaryLabel: _draft.text.isNotEmpty
                      ? 'Update entry'
                      : 'Generate draft',
                  onPrimary: _busy || !writable || record == null
                      ? null
                      : _draft.text.isNotEmpty
                      ? _update
                      : () => _generate(entry!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
