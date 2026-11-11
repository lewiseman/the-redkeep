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
    (
      'Ocean',
      'Soft ocean waves and sea glass',
      Icons.waves_rounded,
      Color(0xFF527C9C),
    ),
    (
      'Leaves',
      'Soft green leaves on warm paper',
      Icons.spa_outlined,
      Color(0xFF44766B),
    ),
    (
      'Sunset',
      'A warm peach sunset with soft clouds',
      Icons.wb_twilight,
      Color(0xFFB5683F),
    ),
    (
      'Stars',
      'A quiet night sky with faint stars',
      Icons.nights_stay_outlined,
      Color(0xFF75619B),
    ),
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
        Text(
          'Artwork',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _Canvas(
          imageKey: widget.imageKey,
          paper: widget.paper,
          painting: painting,
          onStop: ref.read(_jobs.notifier).cancel,
          onRemove: painting ? null : widget.onRemove,
        ),
        if (canPaint) ...[
          const SizedBox(height: 16),
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
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                padding: const EdgeInsets.all(6),
                child: IconButton.filled(
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
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _ArtChip(
                icon: Icons.photo_library_outlined,
                label: 'Your photo',
                tint: theme.colorScheme.primary,
                onTap: painting || _picking ? null : _photo,
              ),
              if (canPaint)
                for (final (label, prompt, icon, tint) in _ideas) ...[
                  const SizedBox(width: 8),
                  _ArtChip(
                    icon: icon,
                    label: label,
                    tint: tint,
                    selected: _prompt.text == prompt,
                    onTap: painting
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
    final simple = policy?.simplerEffects ?? false;
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
          width: 104,
          height: 156,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .6),
            ),
            boxShadow: simple
                ? null
                : [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: .12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: AnimatedSwitcher(duration: duration, child: page),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
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

/// A rounded pill with a tinted badge, for photos and painting ideas.
class _ArtChip extends StatelessWidget {
  const _ArtChip({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Lift the hue in dark mode so the badge stays legible.
    final hue = scheme.brightness == Brightness.dark
        ? Color.lerp(tint, Colors.white, .35)!
        : tint;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Color.alphaBlend(hue.withValues(alpha: .16), scheme.surface)
            : scheme.surfaceContainerHigh,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? hue : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .5 : 1,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hue.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : icon,
                      size: 18,
                      color: hue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
