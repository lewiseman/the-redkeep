import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';

class NoteReadPage extends ConsumerStatefulWidget {
  const NoteReadPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NoteReadPage> createState() => _NoteReadPageState();
}

class _NoteReadPageState extends ConsumerState<NoteReadPage> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final opened = ref.watch(noteDocumentProvider(widget.id));
    final busy = ref.watch(notesActionsProvider);
    return AppShell(
      child: opened.when(
        loading: () => const Text('Loading note…'),
        error: (_, _) => Column(
          children: [
            const Text('This note could not be loaded.'),
            OutlinedButton(
              onPressed: () => ref.invalidate(noteDocumentProvider(widget.id)),
              child: const Text('Retry loading'),
            ),
          ],
        ),
        data: (value) {
          final note = value.note;
          if (!value.available) {
            return PaperSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Note unavailable',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This note has not been saved, is missing, or was deleted.',
                  ),
                  if (value.draft != null)
                    OutlinedButton(
                      onPressed: () =>
                          context.go(noteLocation(widget.id, edit: true)),
                      child: const Text('Open recovery draft'),
                    ),
                  FilledButton(
                    onPressed: () => context.go(AppDestination.notes.location),
                    child: const Text('Return to Notes'),
                  ),
                ],
              ),
            );
          }
          return PaperSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  noteTitle(note!.text.title),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Saved revision ${note.revision}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () =>
                          context.go(noteLocation(widget.id, edit: true)),
                      child: Text(
                        value.draft == null ? 'Edit note' : 'Resume draft',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => _delete(note),
                      child: const Text('Delete note'),
                    ),
                  ],
                ),
                if (value.draft != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'A separate recovery draft is available. This is the committed version.',
                    ),
                  ),
                if (_error != null)
                  Semantics(liveRegion: true, child: Text(_error!)),
                const SizedBox(height: 24),
                SelectableText(
                  note.text.body.isEmpty
                      ? 'This note is empty.'
                      : note.text.body,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(NoteDocument note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete this note?'),
        content: const Text(
          'The note will leave your saved list. Its text and any recovery draft are retained on this device. Trash controls are not available yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep note'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(notesActionsProvider.notifier).delete(note);
      if (mounted) context.go(AppDestination.notes.location);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Deletion failed or this note changed. The current note is kept; reload and try again.',
        );
      }
    }
  }
}
