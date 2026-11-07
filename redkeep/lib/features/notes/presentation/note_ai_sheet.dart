import 'dart:io';

import 'note_scan_stage.dart';
import 'note_scan_parts.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_job.dart';
import '../../ai/domain/ai_operation.dart';
import '../../sync/application/sync_providers.dart';
import '../application/note_ai_controller.dart';
import '../application/note_ai_sources.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';
import '../data/note_media_store.dart';
import '../domain/note_document.dart';
import '../domain/note_help_contract.dart';
import '../domain/note_image_contract.dart';
import '../domain/note_question_contract.dart';
import '../domain/note_scan_contract.dart';
import '../domain/note_tag.dart';
import '../domain/transform_contract.dart';
import 'note_ai_loading.dart';
import 'note_ai_widgets.dart';
import 'note_writing_widgets.dart';
import 'note_scene.dart';
import 'website/note_website_view.dart';
import '../domain/website/website_render.dart';
import 'website/website_theme_picker.dart';

NoteAiTool noteToolForJob(AiJob job) => switch (job.operation) {
  AiOperation.noteTemplate => NoteAiTool.template,
  AiOperation.noteMetadata => NoteAiTool.metadata,
  AiOperation.noteQuestion => NoteAiTool.search,
  AiOperation.noteSummary => NoteAiTool.summary,
  AiOperation.noteImage => NoteAiTool.image,
  AiOperation.noteScan => NoteAiTool.scan,
  AiOperation.noteBackground => NoteAiTool.background,
  AiOperation.noteWebsite ||
  AiOperation.noteMarkdown => NoteAiTool.presentation,
  _ => NoteAiTool.writing,
};

Future<void> showNoteAiTools(
  BuildContext context,
  String id, {
  bool editor = false,
}) async {
  final openHistory = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: noteAiPaper(context),
    constraints: BoxConstraints(
      maxWidth: 720,
      maxHeight: MediaQuery.sizeOf(context).height * .94,
    ),
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: _NoteToolNavigator(
        id: id,
        editor: editor,
        onHistory: () => Navigator.of(sheetContext).pop(true),
      ),
    ),
  );
  if (openHistory == true && context.mounted) {
    await context.push('/settings/brain/history');
  }
}

class _NoteToolNavigator extends StatefulWidget {
  const _NoteToolNavigator({
    required this.id,
    required this.editor,
    required this.onHistory,
  });
  final String id;
  final bool editor;
  final VoidCallback onHistory;
  @override
  State<_NoteToolNavigator> createState() => _NoteToolNavigatorState();
}

class _NoteToolNavigatorState extends State<_NoteToolNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigator.currentState!.pop(result),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => _NoteToolMenu(
          id: widget.id,
          editor: widget.editor,
          onClose: () => Navigator.of(context).pop(),
          onHistory: widget.onHistory,
        ),
      ),
    ),
  );
}

class _NoteToolMenu extends ConsumerWidget {
  const _NoteToolMenu({
    required this.id,
    required this.editor,
    required this.onClose,
    required this.onHistory,
  });
  final String id;
  final bool editor;
  final VoidCallback onClose, onHistory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(noteDocumentProvider(id));
    final state = editor ? ref.watch(noteEditorProvider(id)).value : null;
    final draft = state?.baseRevision == 0 || opened.value?.note == null;
    final available =
        opened.hasValue && (draft ? state != null : opened.value!.available);
    final canEdit = ref.watch(syncCanEditProvider);
    final narrow =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    Widget card(NoteAiTool tool) => NoteAiToolCard(
      key: ValueKey('note-assistant-${tool.name}'),
      tool: tool,
      horizontal: draft || narrow,
      onTap: available ? () => open(NoteAiToolPage(tool: tool, id: id)) : null,
    );
    List<Widget> group(String name, List<NoteAiTool> tools) => [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(name, style: Theme.of(context).textTheme.labelMedium),
      ),
      for (var i = 0; i < tools.length; i += narrow || draft ? 1 : 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: narrow || draft || i + 1 == tools.length
              ? card(tools[i])
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: card(tools[i])),
                      const SizedBox(width: 10),
                      Expanded(child: card(tools[i + 1])),
                    ],
                  ),
                ),
        ),
    ];
    return Material(
      color: noteAiPaper(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Note AI',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close AI tools',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('note-assistant-actions'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (!available && !draft)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'This note is unavailable.',
                      key: ValueKey('note-assistant-save-first'),
                    ),
                  ),
                if (draft)
                  ...group('Start', [
                    NoteAiTool.template,
                    NoteAiTool.scan,
                    NoteAiTool.background,
                  ])
                else ...[
                  ...group('Edit', [
                    NoteAiTool.writing,
                    NoteAiTool.summary,
                    NoteAiTool.metadata,
                  ]),
                  ...group('Add', [
                    if (canEdit) NoteAiTool.scan,
                    if (opened.value?.note?.details.attachments.any(
                          (a) => a.isImage,
                        ) ==
                        true)
                      NoteAiTool.image,
                  ]),
                  ...group('Appearance', [
                    NoteAiTool.presentation,
                    if (canEdit) NoteAiTool.background,
                  ]),
                ],
                if (!draft)
                  TextButton.icon(
                    onPressed: () => open(NotePriorContentPage(id: id)),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Prior content / recovery'),
                  ),
                TextButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('AI task history'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoteAiToolPage extends ConsumerStatefulWidget {
  const NoteAiToolPage({
    super.key,
    required this.tool,
    this.id,
    this.initialQuery = '',
  });
  final NoteAiTool tool;
  final String? id;

  /// Prefills the question, e.g. from the notes search bar. Nothing is sent
  /// until the person asks.
  final String initialQuery;
  @override
  ConsumerState<NoteAiToolPage> createState() => _NoteAiToolPageState();
}

class _NoteAiToolPageState extends ConsumerState<NoteAiToolPage> {
  late final _input = TextEditingController(text: widget.initialQuery);
  final _question = TextEditingController();
  final _review = TextEditingController();
  final _tags = <String>{};
  String _writing = 'rewrite-note',
      _tone = 'friendly',
      _imageMode = 'describe',
      _presentation = 'website',
      _theme = 'auto',
      _backgroundTone = 'light';
  String? _title, _error, _reviewedJob;
  NoteAttachment? _image;
  TextSelection? _selection;
  bool _working = false, _showBefore = false;
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => ref.read(aiJobsProvider.notifier).restore());
  }

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
    NoteAiTool.summary => AiOperation.noteSummary,
    NoteAiTool.metadata => AiOperation.noteMetadata,
    NoteAiTool.template => AiOperation.noteTemplate,
    NoteAiTool.image => AiOperation.noteImage,
    NoteAiTool.scan => AiOperation.noteScan,
    NoteAiTool.background => AiOperation.noteBackground,
    NoteAiTool.presentation =>
      _presentation == 'website'
          ? AiOperation.noteWebsite
          : AiOperation.noteMarkdown,
    _ => AiOperation.values.firstWhere((o) => o.wireName == _writing),
  };
  bool _matches(AiJob job) =>
      job.operation.isNote &&
      (noteToolForJob(job) == widget.tool ||
          job.operation == AiOperation.noteMarkdown &&
              widget.tool == NoteAiTool.writing) &&
      (widget.tool == NoteAiTool.search ||
          widget.id == job.key ||
          widget.id == null);
  Future<void> _generate() => _run(() async {
    FocusScope.of(context).unfocus();
    final actions = ref.read(noteAiControllerProvider);
    if (widget.tool == NoteAiTool.search) {
      await actions.search(_input.text);
    } else {
      await actions.start(
        _operation,
        widget.id!,
        intent: _writing == 'tone-note'
            ? writingTones[_tone]!.$3
            : _question.text,
        topic: _input.text,
        description: _input.text,
        theme: _theme,
        tone: _backgroundTone,
        image: _image,
        mode: _imageMode,
        question: _imageMode == 'question' ? _question.text : '',
        selectionStart: _selection?.start,
        selectionEnd: _selection?.end,
      );
    }
  });
  Future<void> _apply(AiJob job) => _run(() async {
    final result = await ref
        .read(noteAiControllerProvider)
        .apply(
          job,
          title: _title,
          tags: _tags.toList(),
          reviewedText:
              (job.operation == AiOperation.noteScan ||
                  job.operation == AiOperation.noteImage)
              ? _review.text
              : null,
        );
    if (!mounted) return;
    _reviewedJob = null;
    if (result != null && job.operation == AiOperation.noteMetadata) {
      final prior =
          (await ref.read(notesRepositoryProvider).priorContent(result.id))
              .first;
      if (!mounted) return;
      final repository = ref.read(notesRepositoryProvider);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Title and tags updated.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await repository.restorePriorContent(
                  result.id,
                  prior.id,
                  result.revision,
                );
              } catch (_) {
                if (messenger.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('This note changed, so it was not undone.'),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    }
    if (mounted) Navigator.of(context).maybePop();
  });
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiJobsProvider);
    final job = state.job;
    final mine = job != null && _matches(job);
    if (widget.id != null && isNoteId(widget.id!)) {
      ref.watch(noteDocumentProvider(widget.id!));
    }
    final loading = _working || mine && !job.terminal && state.busy;
    return NoteAiScaffold(
      listKey: const ValueKey('notes-ai-tool-list'),
      tool: widget.tool,
      step: mine && job.text != null
          ? 2
          : mine
          ? 1
          : 0,
      loading: loading && widget.tool != NoteAiTool.scan
          ? NoteAiLoading(
              tool: widget.tool,
              phase: mine ? job.phase : 'preparing',
              onCancel: mine && !job.terminal
                  ? ref.read(aiJobsProvider.notifier).cancel
                  : null,
            )
          : null,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(_error!)),
          ),
        if (state.message != null) Text(state.message!),
        if (job != null && !mine) ...[
          const Text(
            'Another AI task is open. Review or clear it before starting another.',
            key: ValueKey('notes-ai-occupied'),
          ),
          if (job.operation.isNote)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      NoteAiToolPage(tool: noteToolForJob(job), id: job.key),
                ),
              ),
              child: const Text('Open current task'),
            ),
          OutlinedButton(
            onPressed: () => context.push('/settings/brain'),
            child: const Text('Open Grand Maestar'),
          ),
        ] else if (mine)
          ..._task(job, state)
        else
          ..._form(),
      ],
    );
  }

  List<Widget> _form() {
    final note = widget.id == null || !isNoteId(widget.id!)
        ? null
        : ref.watch(noteDocumentProvider(widget.id!)).value?.note;
    return [
      if (widget.tool == NoteAiTool.search)
        TextField(
          key: const ValueKey('notes-ai-search-field'),
          controller: _input,
          maxLength: 300,
          minLines: 1,
          maxLines: 4,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _generate(),
          decoration: const InputDecoration(
            labelText: 'Ask about your notes',
            hintText: 'For example: what did I plan for the garden?',
          ),
        ),
      if (widget.tool == NoteAiTool.template) ...[
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
        const NoteWritingSteps(step: 0),
        NoteAiChoices(
          choices: writingActions,
          selected: _writing,
          onChanged: (String v) => setState(() => _writing = v),
        ),
        if (_writing == 'tone-note')
          NoteAiChoices(
            choices: {for (final e in writingTones.entries) e.key: e.value.$1},
            selected: _tone,
            onChanged: (String v) => setState(() => _tone = v),
          ),
        if (note != null) ...[
          NoteAiPreview(
            label: _selection == null ? 'Whole saved note' : 'Selected passage',
            child: SelectableText(
              note.text.body,
              onSelectionChanged: (selection, cause) {
                if (cause == SelectionChangedCause.longPress ||
                    cause == SelectionChangedCause.drag ||
                    cause == SelectionChangedCause.tap) {
                  setState(
                    () => _selection = selection.isCollapsed ? null : selection,
                  );
                }
              },
            ),
          ),
          if (_selection != null)
            TextButton(
              onPressed: () => setState(() => _selection = null),
              child: const Text('Use whole note'),
            ),
        ],
      ],
      if (widget.tool == NoteAiTool.image) ...[
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
      if (widget.tool == NoteAiTool.scan) ...[
        _scanStage(_image?.path),
        for (final image
            in note?.details.attachments.where((a) => a.isImage) ??
                const <NoteAttachment>[])
          TextButton(
            onPressed: () => setState(() => _image = image),
            child: Text('Use attached page: ${image.filename}'),
          ),
        if (_image != null)
          FutureBuilder<String?>(
            future: ref.read(noteMediaStoreProvider).scanOriginal(_image!.path),
            builder: (_, snapshot) => snapshot.data == null
                ? const SizedBox.shrink()
                : NoteAiDetails(
                    snapshot.data!,
                    title: 'Original reading from this page',
                  ),
          ),
      ],
      if (widget.tool == NoteAiTool.background) ...[
        NoteAiBackdropIdeas(
          value: _input.text,
          onChanged: (v) => setState(() => _input.text = v),
        ),
        TextField(
          controller: _input,
          maxLength: 240,
          decoration: const InputDecoration(
            labelText: 'Describe the background',
          ),
        ),
        NoteAiChoices(
          choices: const {'light': 'Light', 'dark': 'Dark'},
          selected: _backgroundTone,
          onChanged: (String v) => setState(() => _backgroundTone = v),
        ),
      ],
      if (widget.tool == NoteAiTool.presentation) ...[
        NoteAiChoices(
          choices: const {'website': 'Website', 'markdown': 'Formatted text'},
          selected: _presentation,
          onChanged: (String v) => setState(() => _presentation = v),
        ),
        if (_presentation == 'website') ...[
          WebsiteThemeSwatches(
            selected: _theme,
            auto: true,
            onSelected: (v) => setState(() => _theme = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            maxLength: 240,
            decoration: const InputDecoration(
              labelText: 'Describe the website',
            ),
          ),
          const NoteAiDetails(
            'Your note text stays intact. Only the title, text, chosen theme and number of photos are used. Photos stay on this device.',
            title: 'What is used',
          ),
        ],
      ],
      if (widget.tool == NoteAiTool.summary)
        const Text(
          'Turn the saved note into a few clear lines. Your original note stays intact.',
        ),
      if (widget.tool == NoteAiTool.metadata)
        const Text(
          'Choose which title and tags to keep. Existing tags stay on your note.',
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const ValueKey('notes-ai-generate'),
        onPressed: _generate,
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text(switch (widget.tool) {
          NoteAiTool.search => 'Ask your notes',
          NoteAiTool.summary => 'Summarize',
          NoteAiTool.metadata => 'Suggest title & tags',
          NoteAiTool.scan => 'Read the page',
          _ => 'Generate preview',
        }),
      ),
    ];
  }

  Future<void> _pickImage(bool camera) => _run(() async {
    final image = await ref
        .read(noteMediaStoreProvider)
        .pickPhoto(widget.id!, camera: camera);
    if (mounted && image != null) setState(() => _image = image);
  });
  Widget _retainedScanStage(AiJob job, bool complete) {
    try {
      final image = NoteAttachment.fromMap(
        Map<String, dynamic>.from(noteTaskSource(job.source)['image'] as Map),
      );
      return _scanStage(
        image.path,
        analyzing: !job.terminal,
        compact: complete,
      );
    } catch (_) {
      return const Text(
        'The retained page snapshot is unavailable. Clear this task and choose the page again.',
      );
    }
  }

  Widget _scanStage(
    String? path, {
    bool analyzing = false,
    bool compact = false,
  }) => FutureBuilder<File?>(
    future: path == null
        ? Future.value(null)
        : ref.read(noteMediaStoreProvider).resolve(path),
    builder: (context, snapshot) => NoteScanStage(
      page: snapshot.data?.path,
      analyzing: analyzing,
      compact: compact,
      empty: path == null
          ? NoteScanEmpty(
              onCamera: () => _pickImage(true),
              onGallery: () => _pickImage(false),
            )
          : null,
      overlay: analyzing
          ? NoteScanReading(
              phase: 'running',
              onStop: ref.read(aiJobsProvider.notifier).cancel,
            )
          : path == null || compact
          ? null
          : NoteScanToolbar(
              children: [
                NoteScanTool(
                  icon: Icons.camera_alt_outlined,
                  tooltip: 'Retake photo',
                  onPressed: () => _pickImage(true),
                ),
                NoteScanTool(
                  icon: Icons.photo_library_outlined,
                  tooltip: 'Choose another image',
                  onPressed: () => _pickImage(false),
                ),
                NoteScanTool(
                  icon: Icons.rotate_90_degrees_cw_outlined,
                  tooltip: 'Rotate page',
                  onPressed: _image == null
                      ? null
                      : () => _run(() async {
                          final rotated = await ref
                              .read(noteMediaStoreProvider)
                              .rotate(_image!);
                          if (mounted) setState(() => _image = rotated);
                        }),
                ),
              ],
            ),
    ),
  );

  Widget _imagePreview(String path) => SizedBox(
    height: 220,
    child: ref
        .watch(noteBackgroundImageProvider(path))
        .when(
          data: (image) => image == null
              ? const Text('Image unavailable')
              : Image(image: image, fit: BoxFit.contain),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('Image unavailable'),
        ),
  );
  List<Widget> _task(AiJob job, AiJobState state) {
    final controller = ref.read(aiJobsProvider.notifier);
    final complete = job.phase == 'completed' && job.text != null;
    return [
      Text(
        '${job.operation.label} · ${job.phase} · ${job.destinationLabel}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      if (job.operation == AiOperation.noteScan)
        _retainedScanStage(job, complete),
      if (complete) ..._result(job),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!state.busy &&
              !complete &&
              job.phase != 'cancelled' &&
              job.phase != 'expired')
            OutlinedButton(
              onPressed: controller.retry,
              child: const Text('Retry / retrieve'),
            ),
          if (!job.terminal)
            OutlinedButton(
              onPressed: controller.cancel,
              child: const Text('Cancel task'),
            ),
          TextButton(
            onPressed: () => _run(() async {
              await controller.clear();
              if (mounted) {
                setState(() {
                  _reviewedJob = null;
                  _tags.clear();
                  _title = null;
                });
              }
            }),
            child: Text(complete ? 'Reject / clear preview' : 'Clear task'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _result(AiJob job) {
    try {
      validateNoteAiOutput(job.operation, job.text!, job.source);
    } catch (_) {
      return [
        const Text(
          'This retained preview could not be read safely. Clear it to ask again.',
        ),
      ];
    }
    final source = noteTaskSource(job.source);
    if (job.operation == AiOperation.noteQuestion) {
      final selection = RecallQuestionSelection.decode(
        source['payload'] as String,
      );
      final answer = RecallQuestionAnswer.parse(job.text!, selection);
      return [
        NoteAiPreview(
          label: 'From your notes',
          child: SelectableText(answer.text),
        ),
        Text(
          '${selection.matching} matching notes · ${selection.sources.length} excerpts used',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final citation in answer.citations)
          FutureBuilder<OpenNote>(
            future: ref
                .read(notesRepositoryProvider)
                .openDocument(citation.uuid),
            builder: (context, snapshot) {
              final current = snapshot.data;
              final stale =
                  current != null &&
                  (!current.available ||
                      RecallItem.note(current.note!)?.version !=
                          citation.version);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  citation.title.isEmpty ? 'Untitled note' : citation.title,
                ),
                subtitle: Text(
                  '${citation.text}${stale ? '\nThis source changed or was deleted.' : ''}',
                ),
                onTap: current?.available == true
                    ? () => context.push(noteLocation(citation.uuid))
                    : null,
              );
            },
          ),
      ];
    }
    final note = ref.watch(noteDocumentProvider(job.key)).value;
    final stale =
        note != null &&
        (source['unsaved'] == true
            ? note.note != null ||
                  ref.watch(noteEditorProvider(job.key)).value?.editVersion !=
                      source['editVersion']
            : !note.available || note.note!.revision != source['revision']);
    final canApply =
        note != null &&
        !stale &&
        (source['unsaved'] == true || ref.watch(syncCanEditProvider));
    final result = <Widget>[
      if (stale)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Earlier note version: the source changed. This preview cannot replace the current note.',
            key: ValueKey('notes-ai-stale'),
          ),
        ),
    ];
    if (job.operation == AiOperation.noteMetadata) {
      final suggestions = NoteMetadataSuggestions.parse(
        job.text!,
        NoteMetadataSource.decode(source['payload'] as String),
        library: (ref.watch(noteTagsProvider).value ?? const <String>[])
            .map(NoteTag.tryParse)
            .whereType<NoteTag>(),
      );
      result.addAll([
        ChoiceChip(
          label: const Text('Keep current title'),
          selected: _title == null,
          onSelected: (_) => setState(() => _title = null),
        ),
        for (final title in suggestions.titles)
          ChoiceChip(
            label: Text(title),
            selected: _title == title,
            onSelected: (_) => setState(() => _title = title),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final tag in suggestions.tags)
              FilterChip(
                label: Text('${tag.emoji} ${tag.name}'),
                selected: _tags.contains(tag.encoded),
                onSelected: (v) => setState(() {
                  if (v) {
                    _tags.add(tag.encoded);
                  } else {
                    _tags.remove(tag.encoded);
                  }
                }),
              ),
          ],
        ),
      ]);
    } else if (job.operation == AiOperation.noteBackground) {
      result.add(_imagePreview(backgroundPreviewPath(job.id, job.text!)));
    } else if (job.operation == AiOperation.noteWebsite) {
      result.add(
        FutureBuilder<String>(
          future: websitePageFromOutput(
            job.operation.wireName,
            job.text!,
            source: source['payload'] as String,
          ),
          builder: (_, snapshot) => snapshot.hasError
              ? const Text('This website could not be shown safely.')
              : snapshot.data == null
              ? const Text('Preparing website…')
              : SizedBox(
                  height: 420,
                  child: NoteWebsiteView(
                    html: snapshot.data!,
                    photos: note?.note?.details.attachments ?? const [],
                  ),
                ),
        ),
      );
    } else if (job.operation == AiOperation.noteScan) {
      final scan = NoteScanResult.parse(job.text!);
      if (_reviewedJob != job.id) {
        _review.text = scan.text;
        _reviewedJob = job.id;
      }
      result.addAll([
        if (!scan.readable || scan.unreadableMarks > 0)
          Text(
            'Check unclear words marked [?]. ${scan.unreadableMarks} unreadable places.',
          ),
        if (scan.check != null)
          NoteAiDetails(
            scan.check!.map((line) => line.text).join('\n'),
            title: 'Second reading',
          ),
        if (scan.disagreements.isNotEmpty)
          Text(
            'Check these names and numbers: ${scan.disagreements.join(', ')}',
          ),
        TextField(
          controller: _review,
          minLines: 6,
          maxLines: 16,
          maxLength: 6000,
          decoration: const InputDecoration(
            labelText: 'Check and correct the words',
          ),
        ),
        NoteAiDetails(scan.text, title: 'Original reading'),
      ]);
    } else if (job.operation == AiOperation.noteImage) {
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
            NoteAiPreview(label: entry.key, child: SelectableText(entry.value)),
          );
        }
      }
      result.add(
        TextField(
          controller: _review,
          minLines: 2,
          maxLines: 8,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Insert into the note',
            helperText:
                'Edit before inserting. Appended to the end of the note body.',
          ),
        ),
      );
    } else if (job.operation == AiOperation.noteTemplate) {
      final template = NoteTemplate.parse(job.text!);
      result.add(
        NoteAiPreview(
          label: template.title,
          child: SelectableText(template.body),
        ),
      );
    } else {
      if (source['range'] is String) {
        result.add(
          TextButton(
            onPressed: () => setState(() => _showBefore = !_showBefore),
            child: Text(_showBefore ? 'Show proposal' : 'Show original'),
          ),
        );
      }
      result.add(
        NoteAiPreview(
          label: _showBefore ? 'Original selected text' : 'Your preview',
          child: SelectableText(
            _showBefore && source['range'] is String
                ? TransformSource.decode(source['range'] as String).selected
                : job.text!,
          ),
        ),
      );
    }
    result.addAll([
      const SizedBox(height: 12),
      if (job.operation == AiOperation.noteSummary)
        OutlinedButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: job.text!)),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy summary'),
        )
      else
        FilledButton.icon(
          key: const ValueKey('notes-ai-apply'),
          onPressed:
              canApply &&
                  (job.operation != AiOperation.noteMetadata ||
                      _title != null ||
                      _tags.isNotEmpty)
              ? () => _apply(job)
              : null,
          icon: const Icon(Icons.check_rounded),
          label: Text(
            job.operation == AiOperation.noteMetadata
                ? 'Apply selected'
                : job.operation == AiOperation.noteScan ||
                      job.operation == AiOperation.noteImage
                ? 'Add to note'
                : 'Keep this',
          ),
        ),
    ]);
    return result;
  }
}

class NotePriorContentPage extends ConsumerStatefulWidget {
  const NotePriorContentPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NotePriorContentPage> createState() =>
      _NotePriorContentPageState();
}

class _NotePriorContentPageState extends ConsumerState<NotePriorContentPage> {
  int _revision = 0;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final note = ref.watch(noteDocumentProvider(widget.id)).value?.note;
    return Scaffold(
      appBar: AppBar(title: const Text('Prior content / recovery')),
      body: FutureBuilder<List<NotePriorContent>>(
        key: ValueKey(_revision),
        future: ref.read(notesRepositoryProvider).priorContent(widget.id),
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null) Text(_error!),
            if (snapshot.data?.isEmpty == true)
              const Text('No prior content saved on this device.'),
            for (final prior in snapshot.data ?? const <NotePriorContent>[])
              ExpansionTile(
                title: Text(prior.operation),
                subtitle: Text(prior.created.toLocal().toString()),
                children: [
                  SelectableText('${prior.title}\n\n${prior.body}'),
                  OutlinedButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: prior.body)),
                    child: const Text('Copy prior content'),
                  ),
                  FilledButton(
                    onPressed:
                        note != null &&
                            note.revision == prior.appliedRevision &&
                            ref.watch(syncCanEditProvider)
                        ? () async {
                            try {
                              await ref
                                  .read(notesRepositoryProvider)
                                  .restorePriorContent(
                                    widget.id,
                                    prior.id,
                                    note.revision,
                                  );
                              if (mounted) setState(() => _revision++);
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _error = 'This note changed. Prior content is still available to copy.',
                                );
                              }
                            }
                          }
                        : null,
                    child: const Text('Restore prior content'),
                  ),
                ],
              ),
            TextButton(
              onPressed: () async {
                final remove = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove recovery copies?'),
                    content: const Text('Your current note stays saved.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove copies'),
                      ),
                    ],
                  ),
                );
                if (remove == true) {
                  await ref
                      .read(notesRepositoryProvider)
                      .clearPriorContent(widget.id);
                  if (mounted) setState(() => _revision++);
                }
              },
              child: const Text('Remove recovery copies'),
            ),
          ],
        ),
      ),
    );
  }
}

class RetainedNoteAiPage extends ConsumerWidget {
  const RetainedNoteAiPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(aiJobsProvider).job;
    return job?.operation.isNote == true
        ? NoteAiToolPage(tool: noteToolForJob(job!), id: job.key)
        : Scaffold(
            appBar: AppBar(title: const Text('Notes AI')),
            body: const Center(child: Text('No retained note task.')),
          );
  }
}
