import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../assets/presentation/local_artwork.dart';
import '../application/diary_editor_controller.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_discard_dialog.dart';
import 'diary_entry_page.dart';
import 'diary_paper_stamp.dart';
import 'photos/diary_ink_action.dart';
import 'diary_writing_paper.dart';
import 'diary_day_page.dart';

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
          // Saving lives in the tray at the foot of the page, under the
          // thumb; up here only the rare, careful choice remains.
          actions: [
            if (saved && !value.sourceUnavailable)
              PopupMenuButton<void>(
                tooltip: 'Entry options',
                icon: const Icon(Icons.more_vert_rounded),
                popUpAnimationStyle: AnimationStyle.noAnimation,
                enabled: !value.saving && !ref.watch(diaryActionsProvider),
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
                  data: (state) => _editor(context, state, controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isToday =>
      widget.address.date.isDay &&
      widget.address.date.isCurrent(ref.read(diaryClockProvider)());

  /// Saves today's new writing as a quick, text-only thought, marked with the
  /// old Flow artwork: a plain slip of paper, the paper boat and its name.
  Widget _thoughtSlip(
    DiaryEditorState value,
    DiaryEditorController controller,
  ) {
    final blocked =
        value.saving ||
        value.text.isEmpty ||
        value.sourceUnavailable ||
        !value.changed;
    final colors = Theme.of(context).colorScheme;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return DiaryInkAction(
      key: const ValueKey('diary-save-thought'),
      label: 'Save as thought',
      tooltip: 'Save as a quick thought, words only',
      onPressed: blocked ? null : () => _saveThought(controller),
      child: CustomPaint(
        painter: DiaryPaperStamp(
          paper: Color.lerp(colors.surface, colors.onSurface, .035)!,
          ink: colors.onSurface,
          shadowColor: colors.shadow,
          variant: 3,
          edgeScale: simple ? 0 : .4,
          shadow: !simple && !blocked,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Opacity(
            opacity: blocked ? .5 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LocalArtwork(
                    assetKey: 'navigation.flow.inactive',
                    dimension: 30,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.6,
                      child: Text(
                        'As a thought',
                        maxLines: 2,
                        style: DiaryTypography.of(context).title.copyWith(
                          color: colors.onSurface,
                          fontSize: 21,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One primary action, soaked in ink. Once the original is gone, saving
  /// means keeping a copy.
  Widget _saveSlip(DiaryEditorState value, DiaryEditorController controller) {
    final copy = value.sourceUnavailable;
    final blocked =
        value.saving || value.text.isEmpty || (!copy && !value.changed);
    return DiaryInkSlip(
      label: value.saving
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

  /// The foot of the page, under the thumb and riding just above the
  /// keyboard: a pen stroke, then the ways to keep the writing.
  Widget _tray(DiaryEditorState value, DiaryEditorController controller) {
    final colors = Theme.of(context).colorScheme;
    final thought = value.baseRevision == 0 && _isToday;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            child: DiaryPenLine(
              color: colors.onSurface.withValues(alpha: .16),
              stroke: 5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Each on its own layer: typing repaints the count, never
              // the paper of the slips.
              Expanded(
                flex: 5,
                child: RepaintBoundary(
                  child: thought
                      ? _thoughtSlip(value, controller)
                      : _WordCount(text: value.text.body),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: RepaintBoundary(child: _saveSlip(value, controller)),
              ),
            ],
          ),
        ],
      ),
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
              // And slips away into the tray at the foot.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          colors.surface,
                          colors.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
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
        _tray(state, controller),
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
          onPressed: () => openDiaryDay(context, widget.address.date),
          child: Text('Return to ${widget.address.date.kind.name}'),
        ),
      ],
    ),
  );

  void _edit(DiaryEditorController controller) =>
      controller.edit(DiaryText(body: _body.text));

  Future<void> _save(DiaryEditorController controller) async {
    if (await controller.save() && mounted) await _leave();
  }

  Future<void> _saveThought(DiaryEditorController controller) async {
    if (await controller.saveAsThought() && mounted) await _leave();
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
    if (mounted) openDiaryDay(context, widget.address.date);
  }

  /// Returns to wherever the editor was opened from.
  Future<void> _leave() async {
    // Let PopScope receive the cleared buffer state.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      openDiaryDay(context, widget.address.date);
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

/// How much is on the page, pencilled at the foot of it.
class _WordCount extends StatelessWidget {
  const _WordCount({required this.text});

  final String text;

  static final _words = RegExp(r"[\p{L}\p{N}][\p{L}\p{N}'’-]*", unicode: true);

  @override
  Widget build(BuildContext context) {
    final count = _words.allMatches(text).length;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.6,
        child: Text(
          switch (count) {
            0 => 'A blank page',
            1 => '1 word',
            _ => '$count words',
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DiaryTypography.of(context).title.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: .8),
            fontSize: 20,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
