import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/presentation/rendering_policy.dart';

/// The writing tools of the note editor.
///
/// With the keyboard down it is a small capsule floating over the paper with
/// the note tools. With the keyboard up it sits on top of the keyboard as one
/// row: formatting first, then the note tools and a way to hide the keyboard.
/// Formatting is offered only while the rich [controller] has the caret; a
/// note edited as plain text gets only the note tools.
class NoteFormatBar extends StatelessWidget {
  const NoteFormatBar({
    super.key,
    required this.keyboardOpen,
    required this.controller,
    required this.onAttach,
    required this.onDictate,
    required this.onTags,
    required this.onFormat,
    required this.onHideKeyboard,
    this.showDictate = true,
  });

  /// Height of the row on top of the keyboard.
  static const rowHeight = 56.0;

  /// Space the floating capsule takes over the paper, including its gap.
  static const capsuleExtent = 72.0;

  final bool keyboardOpen;
  final QuillController? controller;
  final VoidCallback? onAttach;
  final VoidCallback? onDictate;

  /// False when the AI provider has no speech-to-text.
  final bool showDictate;
  final VoidCallback? onTags;

  /// Brings the keyboard (and its formatting row) up; null without rich text.
  final VoidCallback? onFormat;
  final VoidCallback onHideKeyboard;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    // Tapping the tools must not count as tapping away from the editor.
    return TextFieldTapRegion(
      child: AnimatedSwitcher(
        duration: policy.duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: keyboardOpen ? _row(context) : _capsule(context),
      ),
    );
  }

  List<Widget> _noteTools() => [
    _Tool(
      tooltip: 'Attach files',
      icon: Icons.attach_file_rounded,
      onPressed: onAttach,
    ),
    if (showDictate)
      _Tool(
        tooltip: 'Dictate a note',
        icon: Icons.mic_none_rounded,
        onPressed: onDictate,
      ),
    _Tool(tooltip: 'Edit tags', icon: Icons.sell_outlined, onPressed: onTags),
  ];

  Widget _capsule(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      key: const ValueKey('note-format-capsule'),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          MediaQuery.paddingOf(context).bottom + 8,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.surface,
            shape: const StadiumBorder(),
            shadows: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: .12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onFormat != null)
                    _Tool(
                      tooltip: 'Format text',
                      icon: Icons.text_format_rounded,
                      onPressed: onFormat,
                    ),
                  ..._noteTools(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = this.controller;
    return Align(
      key: const ValueKey('note-format-row'),
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
          ),
        ),
        child: SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      if (controller != null) ...[
                        _FormatTools(controller: controller),
                        SizedBox(
                          height: 24,
                          child: VerticalDivider(
                            width: 17,
                            color: colors.outlineVariant,
                          ),
                        ),
                      ],
                      ..._noteTools(),
                    ],
                  ),
                ),
              ),
              _Tool(
                tooltip: 'Hide keyboard',
                icon: Icons.keyboard_hide_outlined,
                onPressed: onHideKeyboard,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatting that follows the caret: a tool shows as on where it applies.
class _FormatTools extends StatelessWidget {
  const _FormatTools({required this.controller});
  final QuillController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final style = controller.getSelectionStyle().attributes;
      final header = style[Attribute.header.key]?.value;
      final list = style[Attribute.list.key]?.value;
      final enabled = !controller.readOnly;
      void toggle(Attribute attribute, bool on) => controller.formatSelection(
        on ? Attribute.clone(attribute, null) : attribute,
      );
      void setList(Attribute attribute, bool on) => controller.formatSelection(
        on ? Attribute.clone(Attribute.list, null) : attribute,
      );
      final bold = style.containsKey(Attribute.bold.key);
      final italic = style.containsKey(Attribute.italic.key);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tool(
            tooltip: switch (header) {
              1 => 'Smaller heading',
              2 => 'Normal text',
              _ => 'Heading',
            },
            icon: Icons.title_rounded,
            selected: header != null,
            // Normal → large heading → small heading → normal.
            onPressed: enabled
                ? () => controller.formatSelection(switch (header) {
                    1 => Attribute.h2,
                    2 || 3 => Attribute.header,
                    _ => Attribute.h1,
                  })
                : null,
          ),
          _Tool(
            tooltip: 'Bold',
            icon: Icons.format_bold_rounded,
            selected: bold,
            onPressed: enabled ? () => toggle(Attribute.bold, bold) : null,
          ),
          _Tool(
            tooltip: 'Italic',
            icon: Icons.format_italic_rounded,
            selected: italic,
            onPressed: enabled ? () => toggle(Attribute.italic, italic) : null,
          ),
          _Tool(
            tooltip: 'Bulleted list',
            icon: Icons.format_list_bulleted_rounded,
            selected: list == 'bullet',
            onPressed: enabled
                ? () => setList(Attribute.ul, list == 'bullet')
                : null,
          ),
          _Tool(
            tooltip: 'Numbered list',
            icon: Icons.format_list_numbered_rounded,
            selected: list == 'ordered',
            onPressed: enabled
                ? () => setList(Attribute.ol, list == 'ordered')
                : null,
          ),
          _Tool(
            tooltip: 'Checklist',
            icon: Icons.checklist_rounded,
            selected: list == 'checked' || list == 'unchecked',
            onPressed: enabled
                ? () => setList(
                    Attribute.unchecked,
                    list == 'checked' || list == 'unchecked',
                  )
                : null,
          ),
        ],
      );
    },
  );
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onPressed,
      icon: Icon(icon),
      style:
          IconButton.styleFrom(
            foregroundColor: colors.onSurface,
            minimumSize: const Size.square(48),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.onSurface.withValues(alpha: .1)
                  : null,
            ),
          ),
    );
  }
}
