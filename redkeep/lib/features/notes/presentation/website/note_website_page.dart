import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation_destination.dart';
import '../../../../core/presentation/rendering_policy.dart';
import '../../../sync/application/sync_providers.dart';
import '../../application/notes_providers.dart';
import '../../domain/note_document.dart';
import '../note_ai_desk.dart';
import '../note_ai_widgets.dart';
import '../note_page.dart';
import 'note_website_card.dart';
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

  Future<void> _regenerate(BuildContext context) =>
      showNoteAiTools(context, id, initialTool: NoteAiTool.presentation);

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

    // Two actions stay in the bar while there is room; otherwise everything
    // folds into the menu.
    final roomy =
        MediaQuery.sizeOf(context).width >= 400 &&
        MediaQuery.textScalerOf(context).scale(14) <= 22;
    final shown = note != null && page != null;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _leave(context)),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                note == null ? 'Website' : noteTitle(note.text.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AnimatedSwitcher(
              duration: RenderingPolicyScope.of(context).duration,
              child: outdated
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: NoteWebsiteOutdatedPill(
                        onPressed: () => _explainOutdated(context, canEdit),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          if (shown && roomy) ...[
            IconButton(
              key: const ValueKey('note-website-edit'),
              tooltip: 'Edit text',
              onPressed: canEdit ? () => _editText(context) : null,
              icon: const Icon(Icons.edit_note_rounded),
            ),
            IconButton(
              key: const ValueKey('note-website-regenerate'),
              tooltip: outdated ? 'Build again (text changed)' : 'Build again',
              onPressed: canEdit ? () => _regenerate(context) : null,
              icon: Badge(
                isLabelVisible: outdated,
                smallSize: 8,
                child: const Icon(Icons.auto_awesome_rounded),
              ),
            ),
          ],
          if (shown)
            PopupMenuButton<String>(
              key: const ValueKey('note-website-menu'),
              tooltip: 'More',
              onSelected: (value) => switch (value) {
                'edit' => _editText(context),
                'regenerate' => _regenerate(context),
                'text' => context.push(noteLocation(id)),
                'remove' => _remove(context, ref),
                _ => null,
              },
              itemBuilder: (_) => [
                if (!roomy) ...[
                  PopupMenuItem(
                    value: 'edit',
                    enabled: canEdit,
                    child: const Text('Edit text'),
                  ),
                  PopupMenuItem(
                    value: 'regenerate',
                    enabled: canEdit,
                    child: Text(
                      outdated ? 'Build again (text changed)' : 'Build again',
                    ),
                  ),
                ],
                const PopupMenuItem(value: 'text', child: Text('Read as text')),
                PopupMenuItem(
                  value: 'remove',
                  enabled: canEdit,
                  child: const Text('Remove website'),
                ),
              ],
            ),
          const SizedBox(width: 4),
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
