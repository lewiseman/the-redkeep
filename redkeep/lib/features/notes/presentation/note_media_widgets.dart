import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_jobs.dart';
import '../data/note_media_store.dart';
import '../domain/note_details.dart';
import '../domain/note_colors.dart';
import 'note_artwork_section.dart';
import 'note_color_strip.dart';

// Verify immutable attachments once per mounted strip, not on every keystroke.
final _attachmentFileProvider = FutureProvider.autoDispose
    .family<File?, String>(
      (ref, path) => ref.watch(noteMediaStoreProvider).resolve(path),
      retry: (_, _) => null,
    );

class NoteAttachmentStrip extends ConsumerWidget {
  const NoteAttachmentStrip({
    super.key,
    required this.attachments,
    this.onRemove,
  });
  final List<NoteAttachment> attachments;
  final ValueChanged<int>? onRemove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 140 + MediaQuery.textScalerOf(context).scale(14) * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = attachments[index];
          return SizedBox(
            width: 160,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  try {
                    await ref.read(noteMediaStoreProvider).open(a);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e is FormatException
                                ? e.message
                                : 'This file is unavailable.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ref
                          .watch(_attachmentFileProvider(a.path))
                          .when(
                            data: (file) => file == null
                                ? const Center(
                                    child: Icon(
                                      Icons.file_present_outlined,
                                      semanticLabel:
                                          'File unavailable on this device',
                                    ),
                                  )
                                : a.isImage
                                ? Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                    cacheWidth: 400,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : const Icon(
                                    Icons.description_outlined,
                                    size: 36,
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const Icon(
                              Icons.file_present_outlined,
                              semanticLabel: 'File unavailable on this device',
                            ),
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.filename,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onRemove != null)
                            IconButton(
                              tooltip: 'Remove attachment',
                              onPressed: () => onRemove!(index),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<Map<String, dynamic>?> pickNoteBackground(
  BuildContext context,
  String id,
  NoteDetails details,
) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: BoxConstraints(
    maxWidth: 560,
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
  // The sheet rises above the keyboard so the backdrop prompt stays visible.
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: _BackgroundPicker(id: id, details: details),
  ),
);

class _BackgroundPicker extends ConsumerStatefulWidget {
  const _BackgroundPicker({required this.id, required this.details});
  final String id;
  final NoteDetails details;
  @override
  ConsumerState<_BackgroundPicker> createState() => _BackgroundPickerState();
}

class _BackgroundPickerState extends ConsumerState<_BackgroundPicker> {
  late final Map<String, dynamic> _background = Map.from(
    widget.details.background,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preset = NoteColors.presetForType(_background['type']);
    // Applying mid-painting would discard the artwork being painted.
    final painting = ref
        .watch(aiJobsProvider(NoteArtworkSection.scope(widget.id)))
        .busy;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shrinkWrap: true,
            children: [
              Text(
                'Color & artwork',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose the paper and what is painted on it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              NoteColorStrip(
                selected: preset,
                onSelected: (preset) =>
                    setState(() => _background['type'] = preset.type),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1),
              ),
              NoteArtworkSection(
                id: widget.id,
                imageKey:
                    (_background['image'] ?? _background['asset']) as String?,
                paper: preset.resolveColors(theme.colorScheme).background,
                onImage: (path) => setState(() {
                  _background.remove('asset');
                  _background['image'] = path;
                  _background['image_source'] = 'local';
                }),
                onRemove: () => setState(() {
                  _background.remove('image');
                  _background.remove('asset');
                  _background.remove('image_source');
                }),
              ),
            ],
          ),
        ),
        // Pinned, so Apply is always in reach; it steps aside while typing.
        if (!keyboard)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: FilledButton.icon(
                  key: const ValueKey('note-background-apply'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: painting
                      ? null
                      : () => Navigator.pop(context, _background),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(painting ? 'Painting…' : 'Apply background'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
