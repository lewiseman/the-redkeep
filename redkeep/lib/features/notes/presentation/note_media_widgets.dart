import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/note_media_store.dart';
import '../domain/note_details.dart';
import '../domain/note_colors.dart';
import 'note_scene.dart';

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
  builder: (_) => _BackgroundPicker(id: id, details: details),
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
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    shrinkWrap: true,
    children: [
      Text('Color & artwork', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in NoteColors.presets)
            ChoiceChip(
              label: Text(preset.label),
              selected: _background['type'] == preset.type,
              avatar: CircleAvatar(
                backgroundColor: preset
                    .resolveColors(Theme.of(context).colorScheme)
                    .background,
                radius: 10,
              ),
              onSelected: (_) =>
                  setState(() => _background['type'] = preset.type),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Text('Artwork', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final entry in const {
              'onboarding.chapter.notes': 'Notes',
              'onboarding.chapter.flow': 'Flow',
              'onboarding.chapter.diary': 'Diary',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 110,
                  child: InkWell(
                    onTap: () => setState(() {
                      _background.remove('image');
                      _background.remove('image_source');
                      _background['asset'] = entry.key;
                    }),
                    child: Column(
                      children: [
                        Expanded(
                          child: ref
                              .watch(noteBackgroundImageProvider(entry.key))
                              .when(
                                data: (image) => image == null
                                    ? const SizedBox.shrink()
                                    : Image(image: image, fit: BoxFit.cover),
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) =>
                                    const Icon(Icons.image_outlined),
                              ),
                        ),
                        Text(entry.value),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (_background['image'] is String || _background['asset'] is String) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ref
              .watch(
                noteBackgroundImageProvider(
                  (_background['image'] ?? _background['asset']) as String,
                ),
              )
              .when(
                data: (image) => image == null
                    ? const Text('Image unavailable')
                    : Image(image: image, fit: BoxFit.cover),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const Text('Image unavailable'),
              ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _background.remove('image');
            _background.remove('asset');
            _background.remove('image_source');
          }),
          child: const Text('Remove image'),
        ),
      ],
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  final photo = await ref
                      .read(noteMediaStoreProvider)
                      .pickPhoto(widget.id);
                  if (photo != null && mounted) {
                    setState(() {
                      _background.remove('asset');
                      _background['image'] = photo.path;
                      _background['image_source'] = 'local';
                    });
                  }
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => _error =
                          'Your photos could not be opened. Please try again.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Choose your photo'),
      ),
      if (_error != null) Text(_error!),
      FilledButton(
        onPressed: _busy ? null : () => Navigator.pop(context, _background),
        child: const Text('Apply background'),
      ),
    ],
  );
}
