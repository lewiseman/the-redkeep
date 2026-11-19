export 'note_ai_desk.dart'
    show showNoteAiTools, NoteAiLanding, NoteAiLandingHost;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_job.dart';
import '../../ai/domain/ai_operation.dart';
import '../application/note_ai_controller.dart';
import '../application/note_ai_sources.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';
import '../domain/note_help_contract.dart';
import '../domain/note_image_contract.dart';
import '../domain/note_rich_markdown.dart';
import '../domain/transform_contract.dart';
import 'note_ai_desk.dart';
import 'note_ai_folio.dart';
import 'note_ai_loading.dart';
import 'note_ai_widgets.dart';
import 'note_writing_widgets.dart';

NoteAiTool noteToolForJob(AiJob job) => switch (job.operation) {
  AiOperation.noteTemplate => NoteAiTool.template,
  AiOperation.noteImage => NoteAiTool.image,
  _ => NoteAiTool.writing,
};

class NoteAiToolPage extends ConsumerStatefulWidget {
  const NoteAiToolPage({
    super.key,
    required this.tool,
    this.id,
    this.embedded = false,
    this.onLanded,
  });
  final NoteAiTool tool;
  final String? id;

  /// Inside the note's AI desk: no page chrome, and keeping a result hands a
  /// [NoteAiLanding] to [onLanded] so the desk closes onto the note.
  final bool embedded;
  final ValueChanged<NoteAiLanding>? onLanded;
  @override
  ConsumerState<NoteAiToolPage> createState() => _NoteAiToolPageState();
}

class _NoteAiToolPageState extends ConsumerState<NoteAiToolPage> {
  final _input = TextEditingController();

  final _question = TextEditingController();
  final _review = TextEditingController();
  AiOperation _writing = AiOperation.noteMarkdown;
  String _imageMode = 'describe';
  String? _error, _reviewedJob;
  NoteAttachment? _image;
  TextSelection? _selection;

  /// The paragraphs chosen on the folio; [_selection] spans them.
  Set<int> _passages = {};
  bool _working = false;

  /// The compare wipe: one shows the proposal, zero the original.
  double _split = 1;

  String get _scope => noteAiScope(widget.tool.name, widget.id);

  /// This page's request. Leaving the page cancels it.
  AiJobsProvider get _jobs => aiJobsProvider(_scope);

  @override
  void dispose() {
    _input.dispose();
    _question.dispose();
    _review.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'This action could not finish. Your writing is kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  AiOperation get _operation => switch (widget.tool) {
    NoteAiTool.template => AiOperation.noteTemplate,
    NoteAiTool.image => AiOperation.noteImage,
    _ => _writing,
  };
  bool _matches(AiJob job) =>
      job.operation.isNote &&
      noteToolForJob(job) == widget.tool &&
      (widget.id == job.key || widget.id == null);
  Future<void> _generate() => _run(() async {
    FocusScope.of(context).unfocus();
    final actions = ref.read(noteAiControllerProvider);
    final operation = _operation;
    await actions.start(
      operation,
      widget.id!,
      scope: _scope,
      intent: operation == AiOperation.noteCustom ? _question.text : '',
      topic: _input.text,
      image: _image,
      mode: _imageMode,
      question: _imageMode == 'question' ? _question.text : '',
      selectionStart: _selection?.start,
      selectionEnd: _selection?.end,
    );
  });
  Future<void> _apply(AiJob job) => _run(() async {
    await ref
        .read(noteAiControllerProvider)
        .apply(
          job,
          scope: _scope,
          reviewedText: job.operation == AiOperation.noteImage
              ? _review.text
              : null,
        );
    if (!mounted) return;
    _reviewedJob = null;
    final landed = widget.onLanded;
    if (landed != null) {
      landed(
        NoteAiLanding(
          tool: widget.tool,
          message: _landedMessage(job.operation),
          appended: const {
            AiOperation.noteImage,
            AiOperation.noteTemplate,
          }.contains(job.operation),
        ),
      );
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  });

  String _landedMessage(AiOperation operation) => switch (operation.wireName) {
    'rewrite-note' => 'Rewritten in place',
    'clarify-note' => 'Words polished',
    'expand-note' => 'Detail woven in',
    'tone-note' => 'Tone changed',
    'markdown-note' => 'Note organized',
    'custom-note' => 'Note updated',
    _ => widget.tool.landed,
  };

  /// What the folio shows: the saved note, or a new note's open draft.
  ({String title, String body, List<String> tags, NoteDetails details})?
  _subject() {
    final id = widget.id;
    if (id == null || !isNoteId(id)) return null;
    final saved = ref.watch(noteDocumentProvider(id)).value?.note;
    if (saved != null) {
      return (
        title: saved.text.title,
        body: saved.text.body,
        tags: saved.tags,
        details: saved.details,
      );
    }
    if (!ref.exists(noteEditorProvider(id))) return null;
    final draft = ref.watch(noteEditorProvider(id)).value;
    if (draft == null) return null;
    return (
      title: draft.text.title,
      body: draft.text.body,
      tags: draft.details.tags,
      details: draft.details,
    );
  }

  Widget _folio({
    required Widget child,
    String? status,
    bool inking = false,
    String? imageKey,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: NoteFolio(
      key: const ValueKey('notes-ai-folio'),
      details: _subject()?.details ?? const NoteDetails(),
      status: status,
      inking: inking,
      imageKey: imageKey,
      child: child,
    ),
  );

  Widget _page({
    int? lines = 4,
    String? proposedTitle,
    String? body,
    Widget? footer,
  }) {
    final subject = _subject();
    return NoteFolioPage(
      title: subject?.title ?? '',
      body: body ?? subject?.body ?? '',
      tags: subject?.tags ?? const [],
      proposedTitle: proposedTitle,
      bodyLines: lines,
      footer: footer,
    );
  }

  /// The end of the note fades in above the words the Maester would add.
  Widget _appendedPage(Widget fresh, {String? title}) {
    final subject = _subject();
    final body = subject?.body ?? '';
    // The last two paragraphs, cut on paragraph lines so formatting holds.
    final blocks = noteBlocks(body);
    final tail = blocks.isEmpty
        ? ''
        : body.substring(
            blocks[blocks.length > 2 ? blocks.length - 2 : 0].start,
            blocks.last.end,
          );
    final empty = subject == null || subject.title.trim().isEmpty;
    return _page(
      body: tail,
      lines: 3,
      proposedTitle: title != null && empty ? title : null,
      footer: NoteFreshInk(label: 'ADDED HERE', child: fresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_jobs);
    final job = state.job;
    final mine = job != null && _matches(job);
    if (widget.id != null && isNoteId(widget.id!)) {
      ref.watch(noteDocumentProvider(widget.id!));
    }
    final loading = _working || mine && !job.terminal && state.busy;
    final phase = mine ? job.phase : 'preparing';
    final onCancel = mine && !job.terminal
        ? ref.read(_jobs.notifier).cancel
        : null;
    final error = [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(liveRegion: true, child: Text(_error!)),
        ),
      if (state.message != null) Text(state.message!),
    ];
    if (widget.embedded) {
      return NoteAiScaffold(
        tool: widget.tool,
        embedded: true,
        children: loading
            ? [
                _folio(status: 'Inking…', inking: true, child: _page()),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    noteAiPhaseTitle(widget.tool, phase),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.stop_rounded, size: 20),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ]
            : [...error, if (mine) ..._task(job, state) else ..._form()],
      );
    }
    return NoteAiScaffold(
      listKey: const ValueKey('notes-ai-tool-list'),
      tool: widget.tool,
      loading: loading
          ? NoteAiLoading(tool: widget.tool, phase: phase, onCancel: onCancel)
          : null,
      children: [...error, if (mine) ..._task(job, state) else ..._form()],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  List<Widget> _form() {
    final subject = _subject();
    final note = widget.id == null || !isNoteId(widget.id!)
        ? null
        : ref.watch(noteDocumentProvider(widget.id!)).value?.note;
    final hasFolio = subject != null;
    final customWriting =
        widget.tool == NoteAiTool.writing && _writing == AiOperation.noteCustom;
    final instructionTooLong =
        customWriting &&
        utf8.encode(_question.text.trim()).length > transformIntentBytes;
    final missingInput = customWriting && _question.text.trim().isEmpty;
    return [
      if (hasFolio && widget.tool == NoteAiTool.writing)
        _folio(
          status: _selection == null ? 'Whole note' : 'Selected passage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subject.title.trim().isEmpty
                    ? 'Untitled note'
                    : subject.title.trim(),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              NoteFolioPassages(
                body: subject.body,
                selected: _passages,
                onChanged: (chosen) => setState(() {
                  final blocks = noteBlocks(subject.body);
                  _passages = chosen;
                  _selection = chosen.isEmpty
                      ? null
                      : TextSelection(
                          baseOffset:
                              blocks[chosen.reduce((a, b) => a < b ? a : b)]
                                  .start,
                          extentOffset:
                              blocks[chosen.reduce((a, b) => a > b ? a : b)]
                                  .end,
                        );
                }),
              ),
            ],
          ),
        )
      else if (hasFolio)
        _folio(status: 'Your note', child: _page()),
      if (widget.tool == NoteAiTool.template) ...[
        _label('Start from'),
        NoteAiChoices(
          choices: const {
            'Meeting notes': 'Meeting notes',
            'Trip plan': 'Trip plan',
            'Recipe': 'Recipe',
            'Weekly review': 'Weekly review',
            'Book notes': 'Book notes',
          },
          selected: _input.text,
          onChanged: (String v) => setState(() => _input.text = v),
        ),
        TextField(
          controller: _input,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'What is the note for?'),
        ),
      ],
      if (widget.tool == NoteAiTool.writing) ...[
        Text(
          _selection == null
              ? 'Tap paragraphs above to work on just those.'
              : 'Only the chosen paragraphs will change.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (_selection != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() {
                _selection = null;
                _passages = {};
              }),
              child: const Text('Use whole note'),
            ),
          ),
        const SizedBox(height: 10),
        NoteWritingChoices(
          selected: _writing,
          onChanged: (v) => setState(() => _writing = v),
        ),
        if (customWriting)
          TextField(
            key: const ValueKey('notes-ai-writing-instructions'),
            controller: _question,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Instructions',
              hintText: 'Make it shorter',
              hintMaxLines: 2,
              errorText: instructionTooLong
                  ? 'Shorten your instructions to continue.'
                  : null,
              errorMaxLines: 3,
            ),
          ),
      ],
      if (widget.tool == NoteAiTool.image) ...[
        _label('Choose a photo'),
        for (final a
            in note?.details.attachments.where((a) => a.isImage) ??
                const <NoteAttachment>[])
          ListTile(
            title: Text(a.filename),
            selected: _image?.path == a.path,
            leading: Icon(
              _image?.path == a.path
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            onTap: () => setState(() => _image = a),
          ),
        NoteAiChoices(
          choices: noteImageModes,
          selected: _imageMode,
          onChanged: (String v) => setState(() => _imageMode = v),
        ),
        if (_imageMode == 'question')
          TextField(
            controller: _question,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Your question'),
          ),
      ],
      const SizedBox(height: 18),
      FilledButton.icon(
        key: const ValueKey('notes-ai-generate'),
        onPressed: missingInput || instructionTooLong ? null : _generate,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Write it on the page'),
      ),
    ];
  }

  Future<void> _discard(AiJobs controller) => _run(() async {
    await controller.clear();
    if (mounted) {
      setState(() {
        _reviewedJob = null;
        _split = 1;
      });
    }
  });

  List<Widget> _task(AiJob job, AiJobState state) {
    final controller = ref.read(_jobs.notifier);
    final complete = job.phase == 'completed' && job.text != null;
    return [
      if (complete)
        ..._result(job, onDiscard: () => _discard(controller))
      else ...[
        _folio(status: 'Unchanged', child: _page()),
        if (job.phase == 'cancelled')
          const Text('Stopped. Your note is unchanged.')
        else if (job.terminal)
          const Text('The Maester could not finish. Your note is unchanged.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!state.busy && job.phase != 'cancelled')
              FilledButton.icon(
                onPressed: controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            if (!job.terminal)
              OutlinedButton(
                onPressed: controller.cancel,
                child: const Text('Cancel'),
              ),
            TextButton(
              onPressed: () => _discard(controller),
              child: const Text('Start over'),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _result(AiJob job, {required VoidCallback onDiscard}) {
    try {
      validateNoteAiOutput(job.operation, job.text!, job.source);
    } catch (_) {
      return [
        const Text(
          'This retained preview could not be read safely. Clear it to ask again.',
        ),
        TextButton(onPressed: onDiscard, child: const Text('Clear')),
      ];
    }
    final source = noteTaskSource(job.source);
    final note = ref.watch(noteDocumentProvider(job.key)).value;
    final stale =
        note != null &&
        (source['unsaved'] == true
            ? note.note != null ||
                  ref.watch(noteEditorProvider(job.key)).value?.editVersion !=
                      source['editVersion']
            : !note.available || note.note!.revision != source['revision']);
    final canApply = note != null && !stale;
    final result = <Widget>[
      if (stale)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Earlier note version: the source changed. This preview cannot replace the current note.',
            key: ValueKey('notes-ai-stale'),
          ),
        ),
    ];
    if (job.operation == AiOperation.noteImage) {
      final answer = NoteImageAnswer.parse(job.text!);
      if (_reviewedJob != job.id) {
        _review.text = answer.insertion;
        _reviewedJob = job.id;
      }
      for (final entry in {
        'Visible details': answer.observations,
        'Text in the image': answer.text,
        'Interpretation': answer.inference,
        'Answer': answer.answer,
      }.entries) {
        if (entry.value.isNotEmpty) {
          result.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NoteAiPreview(
                label: entry.key,
                child: SelectableText(entry.value),
              ),
            ),
          );
        }
      }
      result.addAll([
        const SizedBox(height: 8),
        TextField(
          controller: _review,
          minLines: 2,
          maxLines: 8,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Insert into the note',
            helperText: 'Edit before inserting. It lands at the end.',
          ),
        ),
        _livePreview(),
      ]);
    } else if (job.operation == AiOperation.noteTemplate) {
      final template = NoteTemplate.parse(job.text!);
      result.add(
        _folio(
          status: 'Proposal',
          child: _appendedPage(
            NoteFolioText(template.body),
            title: template.title,
          ),
        ),
      );
    } else {
      final range = source['range'] is String
          ? TransformSource.decode(source['range'] as String)
          : null;
      final subject = _subject();
      result.addAll([
        _folio(
          status: 'Proposal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (subject?.title.trim().isEmpty ?? true)
                    ? 'Untitled note'
                    : subject!.title.trim(),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (range == null)
                NoteFolioText(job.text!)
              else
                NoteFolioCompare(
                  key: const ValueKey('notes-ai-compare'),
                  before: range.selected,
                  after: job.text!,
                  split: _split,
                  onChanged: (v) => setState(() => _split = v),
                ),
            ],
          ),
        ),
        if (range != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _split = _split > .5 ? 0 : 1),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(_split > .5 ? 'Show original' : 'Show proposal'),
            ),
          ),
      ]);
    }
    result.addAll([
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const ValueKey('notes-ai-apply'),
        onPressed: canApply ? () => _apply(job) : null,
        icon: const Icon(Icons.check_rounded),
        label: Text(
          job.operation == AiOperation.noteImage
              ? 'Add to note'
              : 'Keep in note',
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          key: const ValueKey('notes-ai-discard'),
          onPressed: onDiscard,
          child: const Text('Discard and try another'),
        ),
      ),
    ]);
    return result;
  }

  /// The reviewed words, shown where they will land as they are edited.
  Widget _livePreview() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _review,
    builder: (context, value, _) => _folio(
      status: 'Where it lands',
      child: _appendedPage(
        // Added words are kept as plain words, exactly as they will land.
        NoteFolioText(
          value.text.trim().isEmpty
              ? '…'
              : markdownFromPlainText(value.text.trim()),
          lines: 8,
        ),
      ),
    ),
  );
}
