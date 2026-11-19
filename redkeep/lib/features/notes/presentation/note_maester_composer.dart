import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/note_maester_attachment.dart';
import 'note_app_bar.dart';
import 'note_scene.dart';

/// Where the person tells the Maester what to change, floating at the
/// bottom of the note page with the note in view above it. It takes the
/// place of the page's bottom pill while open. Photos and files attached
/// here go with the request, shown above the input until it is sent.
///
/// The paperclip swaps the keyboard for the attachment tray in the same
/// place, so the input never moves: [space] is the room kept below the
/// input while the keyboard is away, and the tray is laid out at
/// [trayHeight], the keyboard's own height.
class NoteMaesterComposer extends StatelessWidget {
  const NoteMaesterComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.working,
    required this.onSend,
    required this.onStop,
    this.selection = false,
    this.error,
    this.attachments = const [],
    this.attaching = false,
    this.readsPhotos = true,
    this.onTakePhoto,
    this.onChoosePhotos,
    this.onChooseFiles,
    this.onRemoveAttachment,
    this.trayOpen = false,
    this.space = 0,
    this.trayHeight = 0,
    this.onToggleTray,
    this.onInputTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The Maester is writing: the request is shown, and Send becomes Stop.
  final bool working;

  /// Rewrites only the selected writing rather than the whole note.
  final bool selection;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onStop;

  /// Photos and files that go with the next request.
  final List<NoteMaesterAttachment> attachments;

  /// A picked photo or file is being prepared.
  final bool attaching;

  /// The AI model can read photos; without it only text files attach.
  final bool readsPhotos;
  final VoidCallback? onTakePhoto, onChoosePhotos, onChooseFiles;
  final ValueChanged<int>? onRemoveAttachment;

  /// The tray is shown in place of the keyboard.
  final bool trayOpen;
  final double space, trayHeight;
  final VoidCallback? onToggleTray;

  /// The input was tapped; the keyboard comes back in place of the tray.
  final VoidCallback? onInputTap;

  @override
  Widget build(BuildContext context) => NoteChromeTheme(
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final status =
            error ??
            (working
                ? 'The Maester is writing…'
                : attaching
                ? 'Preparing your attachment…'
                : selection
                ? 'Rewrites the selected writing'
                : null);
        final attached = attachments.isNotEmpty;
        final full = attachments.length >= noteMaesterAttachmentLimit;
        final card = Padding(
          // The tray or keyboard below already keeps clear of the system bar.
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            (space > 0 ? 0 : MediaQuery.paddingOf(context).bottom) + 8,
          ),
          // Tapping here must not count as tapping away from the editor.
          child: TextFieldTapRegion(
            child: DecoratedBox(
              key: const ValueKey('note-maester-composer'),
              decoration: ShapeDecoration(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .5),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: .14),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (status != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            status,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: error != null
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    _AttachmentStrip(
                      attachments: attachments,
                      onRemove: working ? null : onRemoveAttachment,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // While the Maester writes, a ring takes the
                        // paperclip's place.
                        if (working)
                          const _WritingRing()
                        else
                          _AttachButton(
                            open: trayOpen,
                            onPressed: onToggleTray,
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('note-maester-input'),
                            controller: controller,
                            focusNode: focusNode,
                            readOnly: working,
                            onTap: onInputTap,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSend(),
                            decoration: InputDecoration(
                              hintText: attached
                                  ? 'What should the Maester do with it?'
                                  : selection
                                  ? 'How should this part change?'
                                  : 'What should change in this note?',
                              hintMaxLines: 2,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        working
                            ? IconButton.filledTonal(
                                key: const ValueKey('note-maester-stop'),
                                tooltip: 'Stop',
                                onPressed: onStop,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(48),
                                ),
                                icon: const Icon(Icons.stop_rounded),
                              )
                            : ListenableBuilder(
                                listenable: controller,
                                builder: (context, _) => IconButton.filled(
                                  key: const ValueKey('note-maester-send'),
                                  tooltip: 'Send',
                                  // Attachments alone are added to the note.
                                  onPressed:
                                      attaching ||
                                          controller.text.trim().isEmpty &&
                                              !attached
                                      ? null
                                      : onSend,
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size.square(48),
                                  ),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // The same shape with or without the tray, so the input is never
        // rebuilt and keeps its keyboard connection.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            // Laid out at full height and uncovered as the keyboard leaves,
            // so it never reflows while the keyboard slides.
            SizedBox(
              height: space > 0 ? space : 0,
              child: space <= 0
                  ? null
                  : ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: trayHeight,
                        maxHeight: trayHeight,
                        child: _AttachTray(
                          readsPhotos: readsPhotos,
                          enabled: !working && !attaching && !full,
                          full: full,
                          onTakePhoto: onTakePhoto,
                          onChoosePhotos: onChoosePhotos,
                          onChooseFiles: onChooseFiles,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

/// The Maester's seal, ringed while it writes.
class NoteMaesterMark extends StatelessWidget {
  const NoteMaesterMark({super.key, this.working = false, this.size = 40});
  final bool working;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/branding/grand_maestar.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
    if (!working) {
      return SizedBox.square(
        dimension: size + 8,
        child: Center(child: mark),
      );
    }
    final animate = RenderingPolicyScope.of(context).animate;
    return Semantics(
      label: 'The Maester is writing',
      child: SizedBox.square(
        dimension: size + 8,
        child: Stack(
          alignment: Alignment.center,
          children: [
            mark,
            SizedBox.square(
              dimension: size + 6,
              child: CircularProgressIndicator(
                key: const ValueKey('note-maester-working'),
                // Reduced motion keeps a still ring.
                value: animate ? null : .7,
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                color: noteBarButtonStyle(context).foregroundColor
                    ?.resolve(const {}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The paperclip opens the attachment tray; while it is open, the keyboard
/// key brings the keyboard back.
class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.open, this.onPressed});
  final bool open;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('note-maester-attach'),
    tooltip: open ? 'Show keyboard' : 'Attach a photo or file',
    onPressed: onPressed,
    style: IconButton.styleFrom(minimumSize: const Size.square(48)),
    // The emoji keeps its size with large text, like an icon.
    icon: MediaQuery.withNoTextScaling(
      child: Text(
        open ? '⌨️' : '📎',
        style: const TextStyle(fontSize: 22, height: 1),
      ),
    ),
  );
}

/// Where the keyboard was: take a photo, choose photos, or choose a file.
class _AttachTray extends StatelessWidget {
  const _AttachTray({
    required this.readsPhotos,
    required this.enabled,
    required this.full,
    this.onTakePhoto,
    this.onChoosePhotos,
    this.onChooseFiles,
  });
  final bool readsPhotos, enabled, full;
  final VoidCallback? onTakePhoto, onChoosePhotos, onChooseFiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final note = full
        ? 'You can attach up to $noteMaesterAttachmentLimit photos or files.'
        : readsPhotos
        ? 'Photos, and text files (.txt, .md, .csv, .json), go with your request.'
        : 'Your AI model cannot read photos. Text files (.txt, .md, .csv, .json) still work.';
    Widget option(
      String key,
      String emoji,
      String label,
      VoidCallback? action,
    ) {
      final on = enabled && action != null;
      return Expanded(
        child: Material(
          key: ValueKey('note-maester-$key'),
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: on ? action : null,
            child: Opacity(
              opacity: on ? 1 : .4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: MediaQuery.withNoTextScaling(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 30, height: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
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

    return TextFieldTapRegion(
      child: DecoratedBox(
        key: const ValueKey('note-maester-tray'),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: .5)),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            MediaQuery.viewPaddingOf(context).bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Every option is as tall as the tallest label.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    option(
                      'camera',
                      '📷',
                      'Take a photo',
                      readsPhotos ? onTakePhoto : null,
                    ),
                    const SizedBox(width: 10),
                    option(
                      'photos',
                      '🖼️',
                      'Choose photos',
                      readsPhotos ? onChoosePhotos : null,
                    ),
                    const SizedBox(width: 10),
                    option('files', '📄', 'Choose a file', onChooseFiles),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What goes with the next request, each with a way to take it off.
class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments, this.onRemove});
  final List<NoteMaesterAttachment> attachments;
  final ValueChanged<int>? onRemove;

  static const _tile = 64.0;

  @override
  Widget build(BuildContext context) {
    final animate = RenderingPolicyScope.of(context).animate;
    return AnimatedSize(
      duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: attachments.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: _tile + 12,
              child: ListView.separated(
                key: const ValueKey('note-maester-attachments'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                itemCount: attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _AttachmentTile(
                  attachment: attachments[i],
                  size: _tile,
                  onRemove: onRemove == null ? null : () => onRemove!(i),
                ),
              ),
            ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.size,
    this.onRemove,
  });
  final NoteMaesterAttachment attachment;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bytes = attachment.bytes;
    final kind = bytes != null ? 'Photo' : 'File';
    final extension = attachment.name.contains('.')
        ? attachment.name.split('.').last.toUpperCase()
        : 'TEXT';
    return Semantics(
      label: '$kind: ${attachment.name}',
      container: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        cacheWidth: (size * 3).round(),
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      )
                    : ColoredBox(
                        color: colors.secondaryContainer,
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: colors.onSecondaryContainer,
                              ),
                              const SizedBox(height: 2),
                              MediaQuery.withNoTextScaling(
                                child: Text(
                                  extension,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -6,
                right: -6,
                child: IconButton.filled(
                  tooltip: 'Remove ${attachment.name}',
                  onPressed: onRemove,
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.inverseSurface,
                    foregroundColor: colors.onInverseSurface,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown in the composer while the Maester writes.
class _WritingRing extends StatelessWidget {
  const _WritingRing();

  @override
  Widget build(BuildContext context) {
    final animate = RenderingPolicyScope.of(context).animate;
    return Semantics(
      label: 'The Maester is writing',
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              key: const ValueKey('note-maester-working'),
              // Reduced motion keeps a still ring.
              value: animate ? null : .7,
              strokeWidth: 2.5,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
      ),
    );
  }
}
