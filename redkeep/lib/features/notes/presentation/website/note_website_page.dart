import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/rendering_policy.dart';

import '../../../../app/navigation_destination.dart';
import '../../../sync/application/sync_providers.dart';
import '../../application/notes_providers.dart';
import '../../domain/note_checklist.dart';
import '../../domain/note_document.dart';
import '../note_ai_desk.dart';
import '../note_ai_widgets.dart';
import '../note_app_bar.dart';
import '../note_page.dart';
import 'note_website_card.dart';
import 'note_website_remix_sheet.dart';
import 'note_website_view.dart';

/// A note's website on a page of its own. The note's text lives in the note:
/// "Edit text" opens it, and a website made from older text is marked
/// outdated until it is built again.
class NoteWebsitePage extends ConsumerWidget {
  const NoteWebsitePage({super.key, required this.id});
  final String id;

  void _leave(BuildContext context) => context.canPop()
      ? context.pop()
      : context.go(AppDestination.notes.location);

  void _editText(BuildContext context) =>
      context.push(noteLocation(id), extra: NoteOpen.edit);

  Future<NoteAiLanding?> _regenerate(BuildContext context) =>
      showNoteAiTools(context, id, initialTool: NoteAiTool.presentation);

  /// The Maester: remix the page, or build it again from the text.
  Future<void> _change(
    BuildContext context,
    WidgetRef ref, {
    required bool outdated,
    required bool canEdit,
  }) async {
    final change = await showWebsiteChangeSheet(
      context,
      id,
      outdated: outdated,
      canEdit: canEdit,
    );
    if (!context.mounted) return;
    switch (change) {
      case WebsiteChange.rebuild:
        final landing = await _regenerate(context);
        if (landing != null && context.mounted) {
          _offerUndo(context, ref, 'New website built');
        }
      case WebsiteChange.remixed:
        _offerUndo(context, ref, 'Website remixed');
      case null:
        break;
    }
  }

  void _offerUndo(BuildContext context, WidgetRef ref, String message) {
    final websites = ref.read(noteWebsitesProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => websites.undo(id),
          ),
        ),
      );
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    if (await ref.read(noteWebsitesProvider).undo(id) && context.mounted) {
      _offerUndo(context, ref, 'Previous version restored');
    }
  }

  Future<void> _explainOutdated(BuildContext context, bool canEdit) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your text changed',
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'This website was made from an earlier version of the note. Build it again to include your changes. Until then, this one stays as it is.',
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheet),
                    child: const Text('Not now'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('note-website-outdated-regenerate'),
                    onPressed: canEdit
                        ? () {
                            Navigator.pop(sheet);
                            _regenerate(context);
                          }
                        : null,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Build again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  /// When the website was built, in a few words.
  static String _built(BuildContext context, DateTime madeAt) {
    final local = madeAt.toLocal();
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return switch (days) {
      0 => 'built today',
      1 => 'built yesterday',
      _ when local.year == now.year =>
        'built ${DateFormat.MMMd(locale).format(local)}',
      _ => 'built ${DateFormat.yMMMd(locale).format(local)}',
    };
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove website?'),
        content: const Text(
          'Only the website is removed. Your note and its text stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(noteWebsitesProvider).delete(id);
      if (context.mounted) context.go(noteLocation(id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The website could not be removed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(noteDocumentProvider(id));
    final website = ref.watch(noteWebsiteProvider(id));
    final canEdit = ref.watch(syncCanEditProvider);
    final note = opened.value?.available == true ? opened.value!.note : null;
    final page = website.value;
    final outdated =
        note != null && page != null && page.isOutdatedFor(note.text.body);
    final ready = opened.hasValue && website.hasValue;

    // Edit text stays in the bar while there is room; otherwise it folds
    // into the menu. Building again is always the Maester.
    final roomy = MediaQuery.sizeOf(context).width >= 360;
    final shown = note != null && page != null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
        // Room for the 12px inset plus the full 48px round button, as on the
        // note page.
        leadingWidth: 60,
        leading: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: IconButton(
              tooltip: 'Back',
              style: noteBarButtonStyle(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => _leave(context),
            ),
          ),
        ),
        titleSpacing: 8,
        // The bar keeps its height; very large text is eased so the title
        // and status still fit beside the actions.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: _WebsiteTitle(
            title: note == null ? 'Website' : noteTitle(note.text.title),
            status: page == null
                ? null
                : outdated
                ? NoteWebsiteOutdatedPill(
                    key: const ValueKey('status-outdated'),
                    onPressed: () => _explainOutdated(context, canEdit),
                  )
                : Text(
                    'Website · ${_built(context, page.madeAt)}',
                    key: const ValueKey('note-website-made'),
                  ),
          ),
        ),
        actions: [
          if (shown) ...[
            Badge(
              key: const ValueKey('note-website-regenerate'),
              isLabelVisible: outdated,
              smallSize: 10,
              alignment: const AlignmentDirectional(.55, -.55),
              child: NoteAiButton(
                tooltip: outdated
                    ? 'Change website (text changed)'
                    : 'Change website',
                onPressed: canEdit
                    ? () => _change(
                        context,
                        ref,
                        outdated: outdated,
                        canEdit: canEdit,
                      )
                    : null,
              ),
            ),
            if (roomy)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: IconButton(
                  key: const ValueKey('note-website-edit'),
                  tooltip: 'Edit text',
                  style: noteBarButtonStyle(context),
                  onPressed: canEdit ? () => _editText(context) : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: PopupMenuButton<String>(
                key: const ValueKey('note-website-menu'),
                tooltip: 'More',
                style: noteBarButtonStyle(context),
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) => switch (value) {
                  'edit' => _editText(context),
                  'regenerate' => _regenerate(context),
                  'undo' => _undo(context, ref),
                  'text' => context.push(noteLocation(id)),
                  'remove' => _remove(context, ref),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (!roomy)
                    PopupMenuItem(
                      value: 'edit',
                      enabled: canEdit,
                      child: const ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit text'),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'regenerate',
                    enabled: canEdit,
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_rounded),
                      title: const Text('Build again'),
                      subtitle: outdated
                          ? const Text('Your text changed')
                          : null,
                    ),
                  ),
                  if (page.canUndo)
                    PopupMenuItem(
                      key: const ValueKey('note-website-undo'),
                      value: 'undo',
                      enabled: canEdit,
                      child: const ListTile(
                        leading: Icon(Icons.undo_rounded),
                        title: Text('Undo last change'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'text',
                    child: ListTile(
                      leading: Icon(Icons.notes_rounded),
                      title: Text('Read as text'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'remove',
                    enabled: canEdit,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: canEdit ? scheme.error : null,
                      ),
                      title: Text(
                        'Remove website',
                        style: canEdit ? TextStyle(color: scheme.error) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: !ready
          ? const SizedBox.shrink()
          : shown
          ? SafeArea(
              top: false,
              bottom: false,
              child: NoteWebsiteView(
                html: page.html,
                photos: note.details.attachments,
                noteId: id,
                // Only the first value matters: the page keeps its own
                // state while open.
                state: page.state,
                checklist: noteChecklist(note.text.body),
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note == null
                          ? 'This note is unavailable.'
                          : 'This note has no website on this device.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => note == null
                          ? context.go(AppDestination.notes.location)
                          : context.go(noteLocation(id)),
                      child: Text(
                        note == null ? 'Return to Notes' : 'Open the note',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The note's title over a quiet status line: when the website was built,
/// or that it is outdated.
class _WebsiteTitle extends StatelessWidget {
  const _WebsiteTitle({required this.title, this.status});
  final String title;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = this.status;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AnimatedSwitcher(
              duration: RenderingPolicyScope.of(context).duration,
              child: DefaultTextStyle.merge(
                key: ValueKey(status.key),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                child: status,
              ),
            ),
          ),
      ],
    );
  }
}
