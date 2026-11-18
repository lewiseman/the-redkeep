import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import 'note_app_bar.dart';
import 'note_scene.dart';

/// Where the person tells the Maester what to change, floating at the
/// bottom of the note page with the note in view above it. It takes the
/// place of the page's bottom pill while open.
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
                : selection
                ? 'Rewrites the selected writing'
                : null);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.paddingOf(context).bottom + 8,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        NoteMaesterMark(working: working),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('note-maester-input'),
                            controller: controller,
                            focusNode: focusNode,
                            readOnly: working,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSend(),
                            decoration: InputDecoration(
                              hintText: selection
                                  ? 'How should this part change?'
                                  : 'What should change in this note?',
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
                                  onPressed: controller.text.trim().isEmpty
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
