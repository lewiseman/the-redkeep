import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';
import '../application/diary_editor_controller.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_discard_dialog.dart';
import 'diary_entry_page.dart';
import 'diary_writing_paper.dart';

/// A pinned page of the diary to write on. Save is the only commit, and leaving
/// without saving asks first only when there is writing to lose.
class DiaryEditPage extends ConsumerStatefulWidget {
  const DiaryEditPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  ConsumerState<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends ConsumerState<DiaryEditPage> {
  static const _rulesInset = 18.0;

  /// Blank paper above the first line, which the scroll fade sits over. At
  /// rest it hides nothing; scrolled, text melts away beneath the date.
  static const _fadeHeight = 22.0;
  static const _textPadding = EdgeInsets.fromLTRB(28, _fadeHeight, 28, 24);

  final _body = TextEditingController();
  final _scroll = ScrollController();
  bool _loaded = false;
  bool _leaving = false;
  bool _openingMedia = false;

  @override
  void dispose() {
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(diaryEditorProvider(widget.address));
    final value = editor.value;
    final controller = ref.read(diaryEditorProvider(widget.address).notifier);
    final canEdit = ref.watch(syncCanEditProvider);
    final colors = Theme.of(context).colorScheme;
    final saved = value != null && value.baseRevision > 0;
    return PopScope(
      canPop: value == null || (!value.saving && !value.changed),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _leaving || value == null || value.saving) return;
        _leaving = true;
        final discarded = await confirmDiscardWriting(
          context,
          newEntry: value.baseRevision == 0,
        );
        if (discarded) await controller.discard();
        if (mounted && discarded) await _leave();
        _leaving = false;
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        extendBodyBehindAppBar: true,
        // The paper stays put under the keyboard; only the text area shrinks.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          titleSpacing: 0,
          title: _CompactDateTitle(
            label: widget.address.date.label(
              Localizations.localeOf(context).toString(),
            ),
          ),
          forceMaterialTransparency: true,
          actions: [
            if (!saved) ...[
              IconButton(
                tooltip: 'Add photos',
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _canAddMedia(value) ? () => _media('photos') : null,
              ),
              IconButton(
                tooltip: 'Talk to your diary',
                icon: const Icon(Icons.mic_none_rounded),
                onPressed: _canAddMedia(value) ? () => _media('talk') : null,
              ),
            ],
            _saveButton(value, controller, canEdit),
            if (saved && !value.sourceUnavailable)
              PopupMenuButton<void>(
                tooltip: 'Entry options',
                icon: const Icon(Icons.more_vert_rounded),
                popUpAnimationStyle: AnimationStyle.noAnimation,
                enabled:
                    canEdit &&
                    !value.saving &&
                    !ref.watch(diaryActionsProvider),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    onTap: () => _delete(value, controller),
                    child: const Text('Delete entry'),
                  ),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: DiaryWritingBackdrop(
                variant: widget.address.date.weekday,
                pinned:
                    widget.address.date.isDay &&
                    widget.address.date.isCurrent(
                      ref.read(diaryClockProvider)(),
                    ),
              ),
            ),
            Positioned.fill(
              child: DiaryWritingArea(
                child: editor.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => _unavailable(context),
                  data: (state) => _editor(context, state, controller, canEdit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One primary action. Once the original is gone, saving means keeping a copy.
  Widget _saveButton(
    DiaryEditorState? value,
    DiaryEditorController controller,
    bool canEdit,
  ) {
    final copy = value?.sourceUnavailable == true;
    final blocked =
        value == null ||
        value.saving ||
        value.text.isEmpty ||
        (value.baseRevision > 0 && !canEdit) ||
        (!copy && !value.changed);
    return DiaryPaperSaveButton(
      label: value?.saving == true
          ? 'Saving…'
          : copy
          ? 'Save a copy'
          : 'Save',
      onPressed: blocked
          ? null
          : copy
          ? () => _saveCopy(controller)
          : () => _save(controller),
    );
  }

  String _heading(BuildContext context) => diaryPageDate(
    widget.address.date,
    ref.read(diaryClockProvider)(),
    Localizations.localeOf(context).toString(),
  );

  Widget _editor(
    BuildContext context,
    DiaryEditorState state,
    DiaryEditorController controller,
    bool canEdit,
  ) {
    if (!_loaded) {
      _body.text = state.text.body;
      _loaded = true;
    }
    final colors = Theme.of(context).colorScheme;
    final typography = DiaryTypography.of(context).body;
    // Forced, so emoji or a mixed font can't push a line off its rule.
    final strut = StrutStyle.fromTextStyle(typography, forceStrutHeight: true);
    final notice =
        state.message ??
        (state.sourceUnavailable
            ? 'The original entry was deleted. Save a copy to keep this writing as a new entry.'
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateHeading(text: _heading(context)),
        if (notice != null)
          // Scrolls rather than crowding out the writing at large text.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .25,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      notice,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: DiaryRuledLines(
                  scroll: _scroll,
                  style: typography,
                  strut: strut,
                  top: _textPadding.top,
                  inset: _rulesInset,
                ),
              ),
              // Typing and the caret repaint this layer only, never the rules.
              Positioned.fill(
                child: RepaintBoundary(
                  child: TextField(
                    key: const ValueKey('diary-body'),
                    style: typography,
                    strutStyle: strut,
                    controller: _body,
                    scrollController: _scroll,
                    autofocus: state.baseRevision == 0,
                    // Read-only rather than disabled while saving, so the
                    // keyboard stays up if the save fails.
                    readOnly: state.saving,
                    enabled: state.baseRevision == 0 || canEdit,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          'Start writing about your ${widget.address.date.kind.name}…',
                      hintStyle: typography.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: _textPadding,
                    ),
                    onChanged: (_) => _edit(controller),
                  ),
                ),
              ),
              // Writing slips away under the date rather than being cut off.
              // A flat gradient, so no layer or mask has to be composited.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _fadeHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .3, .65, 1],
                        colors: [
                          colors.surface,
                          colors.surface.withValues(alpha: .86),
                          colors.surface.withValues(alpha: .4),
                          colors.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _unavailable(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Editor unavailable. The entry may be missing or deleted.'),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => ref.invalidate(diaryEditorProvider(widget.address)),
          child: const Text('Retry loading'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => context.go(diaryDayLocation(widget.address.date)),
          child: Text('Return to ${widget.address.date.kind.name}'),
        ),
      ],
    ),
  );

  bool _canAddMedia(DiaryEditorState? value) {
    return !_openingMedia &&
        value != null &&
        value.baseRevision == 0 &&
        !value.saving &&
        value.text.isEmpty &&
        widget.address.date.hasStarted(ref.read(diaryClockProvider)()) &&
        (ref.read(syncCanEditProvider) ||
            widget.address.date.isCurrent(ref.read(diaryClockProvider)()));
  }

  Future<void> _media(String kind) async {
    if (_openingMedia) return;
    setState(() => _openingMedia = true);
    try {
      FocusScope.of(context).unfocus();
      final saved = await context.push<bool>(
        kind == 'talk'
            ? '${diaryDayLocation(widget.address.date)}/talk'
            : '${diaryEntryLocation(widget.address.date, widget.address.id)}/photos',
      );
      if (!mounted || saved != true) return;
      await ref.read(diaryEditorProvider(widget.address).notifier).discard();
      if (mounted) await _leave();
    } finally {
      if (mounted) setState(() => _openingMedia = false);
    }
  }

  void _edit(DiaryEditorController controller) =>
      controller.edit(DiaryText(body: _body.text));

  Future<void> _save(DiaryEditorController controller) async {
    if (await controller.save() && mounted) await _leave();
  }

  Future<void> _saveCopy(DiaryEditorController controller) async {
    final id = await controller.saveCopy();
    if (id == null || !mounted) return;
    await controller.discard();
    if (mounted) await _leave();
  }

  Future<void> _delete(
    DiaryEditorState state,
    DiaryEditorController controller,
  ) async {
    final deleted = await deleteDiaryEntry(
      context,
      ref,
      id: widget.address.id,
      revision: state.baseRevision,
    );
    if (!deleted || !mounted) return;
    await controller.discard();
    // Not a pop: the reader this may have opened from no longer has an entry.
    if (mounted) context.go(diaryDayLocation(widget.address.date));
  }

  /// Returns to wherever the editor was opened from.
  Future<void> _leave() async {
    // Let PopScope receive the cleared buffer state.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(diaryDayLocation(widget.address.date));
    }
  }
}

/// Too little room for the handwritten date: with the keyboard up on a small
/// screen, or at large text. The date moves to the app bar instead.
bool _compactWriting(BuildContext context) =>
    MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom <
    440;

/// The date written at the top of the page, in the diary's title hand.
class _DateHeading extends StatelessWidget {
  const _DateHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (_compactWriting(context)) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Semantics(
        header: true,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: FittedBox(
            alignment: AlignmentDirectional.centerStart,
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              key: const ValueKey('diary-writing-date'),
              maxLines: 1,
              style: DiaryTypography.of(context).title
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactDateTitle extends StatelessWidget {
  const _CompactDateTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (!_compactWriting(context)) return const SizedBox.shrink();
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
