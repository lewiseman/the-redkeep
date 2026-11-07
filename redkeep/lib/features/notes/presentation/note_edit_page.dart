import 'dart:async';

import '../../recall/application/recall_controller.dart';

import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';

import 'note_ai_sheet.dart';
import 'note_ai_widgets.dart' show NoteAiTool;
import 'note_app_bar.dart';
import 'note_format_bar.dart';
import 'note_markdown_preview.dart';
import 'note_typography.dart';
import '../domain/note_rich_markdown.dart';
import 'note_scene.dart';
import 'note_media_widgets.dart';
import 'note_tag_picker.dart';
import '../data/note_media_store.dart';
import '../domain/note_colors.dart';
import '../../voice/presentation/voice_capture_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../sync/application/sync_providers.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';
import 'note_paper.dart';

/// The editing state of [NotePage]. Writing saves straight into the note, so
/// there is no Done: [onBack] follows the back button or gesture and runs only
/// once everything is saved (or the changes were discarded).
class NoteEditView extends ConsumerStatefulWidget {
  const NoteEditView({
    super.key,
    required this.id,
    required this.onBack,
    required this.paperKey,
  });
  final String id;

  /// The same paper reading used, so editing continues it in place.
  final GlobalKey paperKey;
  final VoidCallback onBack;
  @override
  ConsumerState<NoteEditView> createState() => _NoteEditViewState();
}

class _NoteEditViewState extends ConsumerState<NoteEditView> {
  final _title = TextEditingController();

  /// Rich editing: the note's Markdown shown as formatted text.
  QuillController? _rich;
  final _richFocus = FocusNode(debugLabel: 'note-body');
  final _richScroll = ScrollController();
  StreamSubscription<DocChange>? _richChanges;

  /// The Markdown the rich editor last stood for.
  String _richMarkdown = '';
  bool _loaded = false;
  bool _leaving = false;
  bool _dictating = false;
  NoteAiLanding? _landing;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _recall = ref.read(recallControllerProvider.notifier);
    // The keyboard row offers formatting only while the body has the caret.
    _richFocus.addListener(() {
      if (mounted) setState(() {});
    });
    // Leaving the app saves too; there is no separate draft to fall back on.
    _lifecycle = AppLifecycleListener(
      onHide: _saveQuietly,
      onPause: _saveQuietly,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(noteEditorProvider(widget.id).future);
        final image = await ref
            .read(noteMediaStoreProvider)
            .recoverPhoto(widget.id);
        if (!mounted || image == null) return;
        final value = ref.read(noteEditorProvider(widget.id)).requireValue;
        ref
            .read(noteEditorProvider(widget.id).notifier)
            .editDetails(
              value.details.copy(
                attachments: [...value.details.attachments, image],
              ),
            );
      } catch (_) {
        /* The pending photo stays recoverable for the next visit. */
      }
    });
  }

  /// Captured up front: indexing is nudged after the page is gone.
  late final RecallController _recall;

  void _saveQuietly() {
    if (!mounted) return;
    final editor = ref.read(noteEditorProvider(widget.id));
    if (editor.hasValue) {
      ref.read(noteEditorProvider(widget.id).notifier).save();
    }
  }

  /// Saves, then leaves editing. Stays put with the message when it can't.
  Future<void> _finish(VoidCallback leave) async {
    if (_leaving) return;
    _leaving = true;
    try {
      final editor = ref.read(noteEditorProvider(widget.id));
      if (!editor.hasValue ||
          await ref.read(noteEditorProvider(widget.id).notifier).save()) {
        if (mounted) {
          FocusScope.of(context).unfocus();
          leave();
        }
      }
    } finally {
      _leaving = false;
    }
  }

  @override
  void dispose() {
    // Leaving the editor indexes the note soon, instead of after each pause.
    _recall.flushSoon();
    _lifecycle.dispose();
    _title.dispose();
    _richChanges?.cancel();
    _rich?.dispose();
    _richFocus.dispose();
    _richScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(noteEditorProvider(widget.id), (_, next) {
      if (!_loaded || next.value == null) return;
      final text = next.value!.text;
      if (_title.text != text.title) _title.text = text.title;
      // AI results, sync imports, dictation and Discard replace the body.
      if (_bodyText != text.body) setState(() => _loadBody(text.body));
    });
    final editor = ref.watch(noteEditorProvider(widget.id));
    final value = editor.value;
    final controller = ref.read(noteEditorProvider(widget.id).notifier);
    final readOnly =
        value != null &&
        value.baseRevision > 0 &&
        !ref.watch(syncCanEditProvider);
    // Until the editor has loaded, the saved note keeps the scene and paper
    // exactly as reading showed them.
    final saved = ref.watch(noteDocumentProvider(widget.id)).value?.note;
    final details = value?.details ?? saved?.details ?? const NoteDetails();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Room for the floating tools; on top of the keyboard the paper simply
    // ends above them.
    final toolsExtent = keyboardOpen ? 0.0 : NoteFormatBar.capsuleExtent;
    final paperColor = NoteColors.fromBackground(
      Theme.of(context).colorScheme,
      details.background,
    ).background;
    return NoteScene(
      details: details,
      seed: widget.id.hashCode,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _finish(widget.onBack);
        },
        child: Scaffold(
          appBar: NoteAppBar(
            backTooltip: 'Close editor',
            onBack: () => _finish(widget.onBack),
            actions: [
              NoteAiButton(
                onPressed: value == null
                    ? null
                    : () async {
                        final landing = await showNoteAiTools(
                          context,
                          widget.id,
                          editor: true,
                        );
                        if (!mounted || landing == null) return;
                        // A new website opens on its own page.
                        if (landing.tool == NoteAiTool.presentation) {
                          this.context.push(noteWebsiteLocation(widget.id));
                          return;
                        }
                        setState(() => _landing = landing);
                      },
              ),
              NoteBarEntrance(
                child: IconButton(
                  tooltip: 'Choose note background',
                  style: noteBarButtonStyle(context),
                  icon: const Icon(Icons.color_lens_outlined),
                  onPressed: value == null || readOnly ? null : _background,
                ),
              ),
            ],
          ),
          body: SafeArea(
            // The paper runs to the bottom edge; the tools float over it.
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: keyboardOpen ? NoteFormatBar.rowHeight : 0,
                    ),
                    child: editor.when(
                      loading: () => NotePaper(
                        key: widget.paperKey,
                        color: paperColor,
                        isPreviewMode: false,
                        readOnly: true,
                        bottomPadding: toolsExtent,
                        onEdit: () {},
                        children: [
                          SliverToBoxAdapter(
                            child: Semantics(
                              label: 'Opening editor…',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    noteTitle(saved?.text.title ?? ''),
                                    style: _titleStyle,
                                  ),
                                  if (saved?.tags.isNotEmpty == true) ...[
                                    const SizedBox(height: 20),
                                    _NoteTagWrap(tags: saved!.tags),
                                  ],
                                  const SizedBox(height: 20),
                                  if (saved?.text.body.isNotEmpty == true)
                                    NoteMarkdownPreview(text: saved!.text.body),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      error: (_, _) => SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('This note is missing or was deleted.'),
                            OutlinedButton(
                              onPressed: () =>
                                  ref.invalidate(noteEditorProvider(widget.id)),
                              child: const Text('Retry loading'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  context.go(AppDestination.notes.location),
                              child: const Text('Return to Notes'),
                            ),
                          ],
                        ),
                      ),
                      data: (state) {
                        if (!_loaded) {
                          _title.text = state.text.title;
                          _loadBody(state.text.body);
                          _loaded = true;
                        }
                        _rich?.readOnly = readOnly;
                        return NotePaper(
                          key: widget.paperKey,
                          color: paperColor,
                          isPreviewMode: false,
                          readOnly: readOnly,
                          bottomPadding: toolsExtent,
                          onEdit: () {},
                          children: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  NoteAttachmentStrip(
                                    attachments: state.details.attachments,
                                    onRemove: readOnly
                                        ? null
                                        : (index) => controller.editDetails(
                                            state.details.copy(
                                              attachments: [
                                                ...state.details.attachments,
                                              ]..removeAt(index),
                                            ),
                                          ),
                                  ),
                                  if (readOnly)
                                    const Text(
                                      'This device is add-only. Reclaim primary in Sync & devices to edit.',
                                    ),
                                  TextField(
                                    key: const ValueKey('note-title'),
                                    controller: _title,
                                    enabled: !readOnly,
                                    style: _titleStyle,
                                    decoration: const InputDecoration(
                                      labelText: 'Title',
                                      hintText: 'Note Title…',
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    maxLines: null,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    onChanged: (_) => _edit(controller),
                                  ),
                                  // Same order and gaps as reading, so text stays put.
                                  if (state.details.tags.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    _NoteTagWrap(tags: state.details.tags),
                                  ],
                                  const SizedBox(height: 20),
                                  if (_rich case final rich?)
                                    QuillEditor(
                                      key: const ValueKey('note-body'),
                                      controller: rich,
                                      focusNode: _richFocus,
                                      scrollController: _richScroll,
                                      config: QuillEditorConfig(
                                        // The paper scrolls; the editor just grows.
                                        scrollable: false,
                                        placeholder: 'Write your note…',
                                        customStyles: NoteTypography.of(context)
                                            .editor(),
                                        minHeight: 120,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      state.message ??
                                          (state.saving ? 'Saving…' : ''),
                                      key: const ValueKey('note-save-status'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  if (state.conflict) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton(
                                          onPressed: state.saving
                                              ? null
                                              : () async {
                                                  final id = await controller
                                                      .saveCopy();
                                                  if (context.mounted &&
                                                      id != null) {
                                                    context.go(
                                                      noteLocation(id),
                                                    );
                                                  }
                                                },
                                          child: const Text('Save a copy'),
                                        ),
                                        OutlinedButton(
                                          onPressed: state.saving
                                              ? null
                                              : () => _discard(controller),
                                          child: const Text('Discard changes'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (value != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: NoteBarEntrance(
                      child: NoteFormatBar(
                        keyboardOpen: keyboardOpen,
                        controller: _richFocus.hasFocus ? _rich : null,
                        onAttach: readOnly ? null : _attach,
                        onDictate: readOnly || _dictating ? null : _dictate,
                        showDictate: ref
                            .watch(aiCapabilitiesProvider)
                            .contains(AiCapability.transcription),
                        onTags: readOnly ? null : _tags,
                        onFormat: _rich == null || readOnly
                            ? null
                            : _richFocus.requestFocus,
                        onHideKeyboard: () => FocusScope.of(context).unfocus(),
                      ),
                    ),
                  ),
                // Only the seal itself takes touches; writing continues below.
                Positioned.fill(
                  child: NoteAiLandingHost(
                    landing: _landing,
                    details: details,
                    onDismissed: () => setState(() => _landing = null),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editTool(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : 'This change could not be kept. Your writing is safe.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _attach() => _editTool(() async {
    final added = await ref.read(noteMediaStoreProvider).pickFiles();
    if (!mounted || added.isEmpty) return;
    final value = ref.read(noteEditorProvider(widget.id)).requireValue;
    if (value.details.attachments.length + added.length > 40) {
      throw const FormatException('Use up to 40 attachments per note.');
    }
    ref
        .read(noteEditorProvider(widget.id).notifier)
        .editDetails(
          value.details.copy(
            attachments: [...value.details.attachments, ...added],
          ),
        );
  });
  Future<void> _background() => _editTool(() async {
    final value = ref.read(noteEditorProvider(widget.id)).requireValue;
    final background = await pickNoteBackground(
      context,
      widget.id,
      value.details,
    );
    if (!mounted || background == null) return;
    final latest = ref.read(noteEditorProvider(widget.id)).requireValue;
    ref
        .read(noteEditorProvider(widget.id).notifier)
        .editDetails(latest.details.copy(background: background));
  });
  Future<void> _tags() => _editTool(() async {
    final value = ref.read(noteEditorProvider(widget.id)).requireValue;
    final tags = await NoteTagPicker.show(
      context,
      currentTags: value.details.tags,
    );
    if (!mounted || tags == null) return;
    final latest = ref.read(noteEditorProvider(widget.id)).requireValue;
    ref
        .read(noteEditorProvider(widget.id).notifier)
        .editDetails(latest.details.copy(tags: tags));
  });
  Future<void> _dictate() async {
    if (_dictating) return;
    setState(() => _dictating = true);
    try {
      final editor = ref.read(noteEditorProvider(widget.id).notifier);
      if (!await editor.save() || !mounted) return;
      final expected = ref.read(noteEditorProvider(widget.id)).requireValue;
      FocusScope.of(context).unfocus();
      final text = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const VoiceCapturePage(title: 'Dictate a note'),
        ),
      );
      if (!mounted || text == null) return;
      final accepted = await editor.appendReviewedTranscript(
        expected: expected,
        transcript: text,
        stillCurrent: () => mounted,
      );
      if (!mounted) return;
      if (accepted) {
        final next = ref.read(noteEditorProvider(widget.id)).requireValue;
        setState(() => _loadBody(next.text.body));
        await editor.save();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The note changed during capture. Your transcript is kept; open the microphone to review it again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dictating = false);
    }
  }

  void _edit(NoteEditorController controller) =>
      controller.edit(PlainTextDocument(title: _title.text, body: _bodyText));

  /// The note body as Markdown.
  String get _bodyText => _richMarkdown;

  /// Shows [markdown] in the rich editor. Markdown outside what the editor
  /// supports opens as its literal text. Nothing about the note is converted
  /// until the writer changes it.
  void _loadBody(String markdown) {
    _richChanges?.cancel();
    _richChanges = null;
    final document = Document.fromDelta(richDocumentFor(markdown));
    final rich = _rich ??= QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    if (!identical(rich.document, document)) rich.document = document;
    _richMarkdown = markdown;
    _richChanges = rich.document.changes.listen((_) {
      final written = markdownFromRich(rich.document.toDelta());
      if (written == _richMarkdown) return;
      _richMarkdown = written;
      _edit(ref.read(noteEditorProvider(widget.id).notifier));
    });
  }

  Future<void> _discard(NoteEditorController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Discard your changes?'),
        content: const Text(
          'The writing in this editor will be removed. The saved note is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep writing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    controller.discardChanges();
    widget.onBack();
  }
}

const _titleStyle = TextStyle(
  fontSize: 24,
  height: 1.3,
  fontWeight: FontWeight.bold,
);

/// The note's tags as reading lays them out.
class _NoteTagWrap extends StatelessWidget {
  const _NoteTagWrap({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Chip(
              label: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis),
              shape: const StadiumBorder(),
            ),
          ),
      ],
    ),
  );
}
