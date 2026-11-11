import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../sync/application/sync_providers.dart';
import '../application/note_ai_controller.dart';
import '../application/note_ai_sources.dart';
import '../data/note_media_store.dart';
import '../domain/note_background_contract.dart';
import 'note_scene.dart';

/// The artwork half of the background sheet: one canvas showing what the note
/// will wear, a line to describe new artwork, and quick starting points.
/// Nothing reaches the note until the sheet's own Apply.
class NoteArtworkSection extends ConsumerStatefulWidget {
  const NoteArtworkSection({
    super.key,
    required this.id,
    required this.imageKey,
    required this.paper,
    required this.onImage,
    required this.onRemove,
  });

  final String id;

  /// The chosen image (generated, photo or older artwork), if any.
  final String? imageKey;

  /// The chosen paper color, shown behind and around the artwork.
  final Color paper;
  final ValueChanged<String> onImage;
  final VoidCallback onRemove;

  /// The request that paints artwork for [id]; the sheet waits on it.
  static String scope(String id) => noteAiScope('background', id);

  @override
  ConsumerState<NoteArtworkSection> createState() => _NoteArtworkSectionState();
}

class _NoteArtworkSectionState extends ConsumerState<NoteArtworkSection> {
  static const _ideas = [
    ('Ocean', 'Soft ocean waves and sea glass', Icons.waves_rounded),
    ('Leaves', 'Soft green leaves on warm paper', Icons.spa_outlined),
    ('Sunset', 'A warm peach sunset with soft clouds', Icons.wb_twilight),
    ('Stars', 'A quiet night sky with faint stars', Icons.nights_stay_outlined),
  ];

  final _prompt = TextEditingController();
  String _tone = 'light';
  bool _picking = false;
  String? _error;

  AiJobsProvider get _jobs =>
      aiJobsProvider(NoteArtworkSection.scope(widget.id));

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _paint() async {
    final text = _prompt.text.trim();
    if (text.isEmpty || ref.read(_jobs).busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    try {
      await ref
          .read(noteAiControllerProvider)
          .start(
            AiOperation.noteBackground,
            widget.id,
            scope: NoteArtworkSection.scope(widget.id),
            description: text,
            tone: _tone,
          );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'The artwork could not be painted. Try again.',
        );
      }
      return;
    }
    if (!mounted) return;
    final job = ref.read(_jobs).job;
    if (job?.phase == 'completed' && job!.text != null) {
      widget.onImage(backgroundPreviewPath(job.id, job.text!));
    }
  }

  Future<void> _photo() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final photo = await ref.read(noteMediaStoreProvider).pickPhoto(widget.id);
      if (photo != null && mounted) widget.onImage(photo.path);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your photos could not be opened. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(_jobs);
    final painting = state.busy;
    final canPaint =
        AiOperation.noteBackground.available && ref.watch(syncCanEditProvider);
    final error = _error ?? state.message;
    final dark = _tone == 'dark';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Artwork', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _Canvas(
          imageKey: widget.imageKey,
          paper: widget.paper,
          painting: painting,
          onStop: ref.read(_jobs.notifier).cancel,
          onRemove: painting ? null : widget.onRemove,
        ),
        if (canPaint) ...[
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('note-artwork-prompt'),
            controller: _prompt,
            enabled: !painting,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(noteBackgroundPromptChars),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _paint(),
            decoration: InputDecoration(
              hintText: 'Describe artwork to paint',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: IconButton(
                tooltip: dark ? 'Dark artwork' : 'Light artwork',
                onPressed: painting
                    ? null
                    : () => setState(() => _tone = dark ? 'light' : 'dark'),
                icon: Icon(
                  dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                ),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton.filledTonal(
                  key: const ValueKey('note-artwork-paint'),
                  tooltip: 'Paint artwork',
                  onPressed: painting || _prompt.text.trim().isEmpty
                      ? null
                      : _paint,
                  icon: const Icon(Icons.brush_rounded),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Your photo'),
                onPressed: painting || _picking ? null : _photo,
              ),
              if (canPaint)
                for (final (label, prompt, icon) in _ideas) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    tooltip: prompt,
                    onPressed: painting
                        ? null
                        : () => setState(() {
                            _prompt.text = prompt;
                            _prompt.selection = TextSelection.collapsed(
                              offset: prompt.length,
                            );
                          }),
                  ),
                ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The note as a small upright page (the artwork's 2:3 shape), with what is
/// happening to it and what can be done beside it.
class _Canvas extends ConsumerWidget {
  const _Canvas({
    required this.imageKey,
    required this.paper,
    required this.painting,
    required this.onStop,
    required this.onRemove,
  });

  final String? imageKey;
  final Color paper;
  final bool painting;
  final VoidCallback onStop;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final policy = context
        .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()
        ?.policy;
    final animate = policy?.animate ?? !MediaQuery.disableAnimationsOf(context);
    final duration = policy?.duration ?? Duration.zero;
    final ink = ThemeData.estimateBrightnessForColor(paper) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final key = imageKey;
    final loaded = key == null
        ? null
        : ref.watch(noteBackgroundImageProvider(key));
    final image = loaded?.value;
    final missing =
        loaded != null && (loaded.hasError || loaded.hasValue && image == null);

    final Widget page;
    if (painting) {
      page = Center(
        key: const ValueKey('painting'),
        child: animate
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: ink),
              )
            : Icon(Icons.brush_rounded, color: ink),
      );
    } else if (image != null) {
      page = Image(
        key: ValueKey(key),
        image: image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      // A few faint lines of writing, so the paper reads as a note page.
      page = Padding(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in const [.7, 1.0, .9, 1.0, .6])
              FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final (title, detail) = painting
        ? ('Painting your artwork…', 'A tall page to fit your note.')
        : key == null
        ? ('No artwork yet', 'Describe some below, or use a photo.')
        : missing
        ? ('Image unavailable', 'Choose or paint another.')
        : ('Artwork ready', 'Apply to set it behind your note.');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: duration,
          width: 96,
          height: 144,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: AnimatedSwitcher(duration: duration, child: page),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (painting)
                  TextButton.icon(
                    onPressed: onStop,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text('Stop'),
                  )
                else if (key != null && onRemove != null)
                  TextButton.icon(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('Remove artwork'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
