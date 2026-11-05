import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/confirm_discard_changes.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';
import '../application/diary_editor_controller.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_entry_page.dart';

/// A plain page for writing. Save is the only commit, and leaving without
/// saving asks first only when there is writing to lose.
class DiaryEditPage extends ConsumerStatefulWidget {
  const DiaryEditPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  ConsumerState<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends ConsumerState<DiaryEditPage> {
  /// The width of the day sheet's text, so writing keeps its line lengths.
  static const _maxWidth = 608.0;

  final _body = TextEditingController();
  bool _loaded = false;
  bool _leaving = false;
  bool _openingMedia = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

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
        final discarded = await confirmDiscardChanges(context);
        if (discarded) await controller.discard();
        if (mounted && discarded) await _leave();
        _leaving = false;
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(
            widget.address.date.label(
              Localizations.localeOf(context).toString(),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
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
        body: SafeArea(
          top: false,
          child: editor.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => _unavailable(context),
            data: (state) => _editor(context, state, controller, canEdit),
          ),
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
    // Flexible with a scaled label: at large text on a narrow screen the whole
    // word stays readable and the app bar's other actions stay on screen.
    return Flexible(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: blocked
              ? null
              : copy
              ? () => _saveCopy(controller)
              : () => _save(controller),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value?.saving == true
                  ? 'Saving…'
                  : copy
                  ? 'Save a copy'
                  : 'Save',
            ),
          ),
        ),
      ),
    );
  }

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
    final notice =
        state.message ??
        (state.sourceUnavailable
            ? 'The original entry was deleted. Save a copy to keep this writing as a new entry.'
            : null);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null)
                // Scrolls rather than crowding out the writing at large text.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .4,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                child: TextField(
                  key: const ValueKey('diary-body'),
                  style: typography,
                  controller: _body,
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
                    contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  ),
                  onChanged: (_) => _edit(controller),
                ),
              ),
            ],
          ),
        ),
      ),
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
