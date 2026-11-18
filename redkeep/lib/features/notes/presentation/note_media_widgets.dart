import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/application/sync_providers.dart';
import '../data/note_media_store.dart';
import '../domain/note_details.dart';
import '../domain/note_colors.dart';
import 'note_artwork_section.dart';
import 'note_color_strip.dart';
import 'note_scene.dart';

// Verify immutable attachments once per mounted view, not on every keystroke.
final _attachmentFileProvider = FutureProvider.autoDispose
    .family<File?, String>(
      (ref, path) => ref.watch(noteMediaStoreProvider).resolve(path),
      retry: (_, _) => null,
    );

/// Opens [attachment] in the device's viewer, or says why it cannot yet.
Future<void> _openAttachment(
  BuildContext context,
  WidgetRef ref,
  NoteAttachment attachment,
) async {
  if (ref.read(mediaRestorePendingProvider) &&
      ref.read(_attachmentFileProvider(attachment.path)).value == null) {
    unawaited(ref.read(backupActionsProvider).prioritizeMedia(attachment.path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Still restoring. This file is next.')),
    );
    return;
  }
  try {
    await ref.read(noteMediaStoreProvider).open(attachment);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException ? e.message : 'This file is unavailable.',
          ),
        ),
      );
    }
  }
}

/// Attachments come back in the background after a restore; refresh any of
/// [attachments] as it lands.
void _listenForRestores(WidgetRef ref, List<NoteAttachment> attachments) {
  ref.listen(restoredMediaProvider, (_, next) {
    final path = next.value;
    if (path != null && attachments.any((a) => a.path == path)) {
      ref.invalidate(_attachmentFileProvider(path));
    }
  });
}

/// The note's photos as instant prints taped to the paper: a light frame
/// with a deeper bottom edge, a strip of tape and a slight tilt each.
///
/// One photo is shown large; several make a row that scrolls past the
/// paper's margins. [onRemove] (editing) gets the index in [attachments].
class NotePhotoPrints extends ConsumerWidget {
  const NotePhotoPrints({super.key, required this.attachments, this.onRemove});
  final List<NoteAttachment> attachments;
  final ValueChanged<int>? onRemove;

  /// Alternating, uneven tilts read as placed by hand.
  static const _tilts = [-.045, .035, -.02, .05, -.035];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [
      for (final (index, a) in attachments.indexed)
        if (a.isImage) (index, a),
    ];
    if (photos.isEmpty) return const SizedBox.shrink();
    _listenForRestores(ref, attachments);
    final width = MediaQuery.sizeOf(context).width;
    if (photos.length == 1) {
      final (index, photo) = photos.single;
      final print = math.min(280.0, width * .66);
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Center(
          child: _Print(
            attachment: photo,
            width: print,
            tilt: -.025,
            onRemove: onRemove == null ? null : () => onRemove!(index),
          ),
        ),
      );
    }
    final print = math.min(168.0, width * .42);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: _Print.heightFor(print) + 28,
        child: ListView.separated(
          key: const ValueKey('note-photo-prints'),
          scrollDirection: Axis.horizontal,
          // Prints slide out past the paper's margin instead of being cut.
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final (index, photo) = photos[i];
            return _Print(
              attachment: photo,
              width: print,
              tilt: _tilts[i % _tilts.length],
              onRemove: onRemove == null ? null : () => onRemove!(index),
            );
          },
        ),
      ),
    );
  }
}

class _Print extends ConsumerWidget {
  const _Print({
    required this.attachment,
    required this.width,
    required this.tilt,
    this.onRemove,
  });
  final NoteAttachment attachment;
  final double width, tilt;
  final VoidCallback? onRemove;

  static const _margin = 8.0, _chin = 26.0;

  static const _tapes = [
    Color(0xffd9a5a0), // dusty rose
    Color(0xffa9bfa0), // sage
    Color(0xff9fb6c9), // sky
    Color(0xffe0c27e), // mustard
  ];
  static double heightFor(double width) =>
      width - 2 * _margin + _margin + _chin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = NoteChrome.of(context);
    final colors = chrome.colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final frame = dark
        ? colors.surfaceContainerHighest
        : const Color(0xfffdfbf6);
    // Muted washi tones, chosen by the photo so each print keeps its tape.
    final tape = _tapes[attachment.path.hashCode.abs() % _tapes.length];
    final restoring = ref.watch(mediaRestorePendingProvider);
    final photo = ref
        .watch(_attachmentFileProvider(attachment.path))
        .when(
          data: (file) => file == null
              ? _Missing(restoring: restoring, color: colors.onSurfaceVariant)
              : Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: (width * 2.5).round(),
                  errorBuilder: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) =>
              _Missing(restoring: false, color: colors.onSurfaceVariant),
        );
    return Transform.rotate(
      angle: tilt,
      child: SizedBox(
        width: width,
        height: heightFor(width),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Photo, ${attachment.filename}',
                excludeSemantics: true,
                child: Material(
                  color: frame,
                  elevation: simple ? 0 : 3,
                  shadowColor: Colors.black.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(3),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openAttachment(context, ref, attachment),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _margin,
                        _margin,
                        _margin,
                        _chin,
                      ),
                      child: ColoredBox(
                        color: colors.surfaceContainerHigh,
                        child: SizedBox.expand(child: photo),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Tape over the top edge, slightly off center.
            Positioned(
              top: -9,
              left: width * .32,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: -tilt * 1.6 - .04,
                  child: Container(
                    width: width * .36,
                    height: 20,
                    decoration: BoxDecoration(
                      color: tape.withValues(alpha: dark ? .62 : .72),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -14,
                right: -14,
                child: IconButton.filledTonal(
                  tooltip: 'Remove attachment',
                  onPressed: onRemove,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.restoring, required this.color});
  final bool restoring;
  final Color color;
  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      restoring
          ? Icons.cloud_download_outlined
          : Icons.image_not_supported_outlined,
      color: color,
      semanticLabel: restoring
          ? 'File still restoring'
          : 'File unavailable on this device',
    ),
  );
}

/// The note's other files as small paper tags after the writing: a punched
/// hole, the kind of file and its name. [onRemove] gets the index in
/// [attachments].
class NoteFileTags extends ConsumerWidget {
  const NoteFileTags({super.key, required this.attachments, this.onRemove});
  final List<NoteAttachment> attachments;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = [
      for (final (index, a) in attachments.indexed)
        if (!a.isImage) (index, a),
    ];
    if (files.isEmpty) return const SizedBox.shrink();
    _listenForRestores(ref, attachments);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        key: const ValueKey('note-file-tags'),
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (index, file) in files)
            _FileTag(
              attachment: file,
              onRemove: onRemove == null ? null : () => onRemove!(index),
            ),
        ],
      ),
    );
  }
}

class _FileTag extends ConsumerWidget {
  const _FileTag({required this.attachment, this.onRemove});
  final NoteAttachment attachment;
  final VoidCallback? onRemove;

  IconData get _icon {
    final type = attachment.type;
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (type.startsWith('audio/')) return Icons.graphic_eq_rounded;
    if (type.startsWith('video/')) return Icons.movie_outlined;
    if (type.startsWith('text/')) return Icons.notes_rounded;
    return Icons.description_outlined;
  }

  String get _kind {
    final name = attachment.filename;
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1 && name.length - dot <= 6) {
      return name.substring(dot + 1).toUpperCase();
    }
    return attachment.type.split('/').first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final ink = colors.onSurface;
    final available =
        ref.watch(_attachmentFileProvider(attachment.path)).value != null;
    final width = MediaQuery.sizeOf(context).width;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(160, width - 64)),
      child: Material(
        color: ink.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: ink.withValues(alpha: .16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openAttachment(context, ref, attachment),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              10,
              8,
              onRemove == null ? 14 : 2,
              8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The tag's punched hole.
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink.withValues(alpha: .35)),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  available ? _icon : Icons.cloud_download_outlined,
                  size: 22,
                  color: ink.withValues(alpha: .8),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: ink, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _kind,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ink.withValues(alpha: .65),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
          ),
        ),
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
                'Choose the paper and a picture to set behind it.',
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
                  onPressed: () => Navigator.pop(context, _background),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Apply background'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
