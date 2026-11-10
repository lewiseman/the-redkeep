import 'package:flutter/material.dart';

import '../../ai/domain/ai_operation.dart';
import 'note_ai_widgets.dart';

const _writingActions = {
  AiOperation.noteMarkdown: 'Organize',
  AiOperation.noteClarify: 'Fix words',
  AiOperation.noteCustom: 'Custom',
};

class NoteWritingChoices extends StatelessWidget {
  const NoteWritingChoices({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final AiOperation selected;
  final ValueChanged<AiOperation> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final single =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      final actions = _writingActions.keys.toList();
      Widget tile(AiOperation action, {bool wide = false}) => _WritingChoice(
        key: ValueKey('writing-action-${action.wireName}'),
        action: action,
        selected: selected == action,
        horizontal: single || wide,
        onTap: () => onChanged(action),
      );
      return Column(
        children: [
          for (var i = 0; i < actions.length; i += single ? 1 : 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: single || i + 1 == actions.length
                  ? tile(actions[i], wide: true)
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: tile(actions[i])),
                          const SizedBox(width: 8),
                          Expanded(child: tile(actions[i + 1])),
                        ],
                      ),
                    ),
            ),
        ],
      );
    },
  );
}

class _WritingChoice extends StatelessWidget {
  const _WritingChoice({
    super.key,
    required this.action,
    required this.selected,
    required this.horizontal,
    required this.onTap,
  });
  final AiOperation action;
  final bool selected, horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.primary;
    final label = Text(
      _writingActions[action]!,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
    final art = SizedBox(
      width: 62,
      height: 42,
      child: action == AiOperation.noteCustom
          ? Icon(Icons.edit_note_rounded, color: ink, size: 36)
          : CustomPaint(
              painter: _WritingPainter(action, ink, noteAiPaper(context)),
            ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: _writingActions[action],
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(
          ink.withValues(alpha: selected ? .12 : .025),
          noteAiPaper(context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: ink.withValues(alpha: selected ? .65 : .18),
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: horizontal
                ? Row(
                    children: [
                      art,
                      const SizedBox(width: 12),
                      Expanded(child: label),
                      if (selected)
                        Icon(Icons.check_circle_rounded, size: 19, color: ink),
                    ],
                  )
                : Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: art),
                          const SizedBox(height: 6),
                          label,
                        ],
                      ),
                      if (selected)
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: ink,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Miniature before/after drawings show what each action does.
class _WritingPainter extends CustomPainter {
  const _WritingPainter(this.action, this.ink, this.paper);
  final AiOperation action;
  final Color ink, paper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 54);
    final pen = Paint()
      ..color = ink
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), pen);
    void sheet(double x, {bool after = false}) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 6, 27, 40),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect.shift(const Offset(2, 2)),
        Paint()..color = ink.withValues(alpha: .1),
      );
      canvas.drawRRect(rect, Paint()..color = paper);
      canvas.drawRRect(rect, pen);
      for (var i = 0; i < 3; i++) {
        final y = 16.0 + i * 5;
        if (after && action == AiOperation.noteMarkdown) {
          canvas.drawCircle(Offset(x + 6, y), 1.1, Paint()..color = ink);
          line(x + 10, y, x + 21, y);
        } else if (!after && action == AiOperation.noteClarify) {
          canvas.drawPath(
            Path()
              ..moveTo(x + 5, y)
              ..lineTo(x + 9, y - 2)
              ..lineTo(x + 13, y + 1)
              ..lineTo(x + 21, y - 1),
            pen,
          );
        } else {
          line(x + 5, y, x + (i == 2 ? 17 : 22), y);
        }
      }
    }

    sheet(2);
    sheet(49, after: true);
    line(33, 26, 44, 26);
    line(40, 22, 44, 26);
    line(40, 30, 44, 26);
    if (action == AiOperation.noteClarify) {
      line(61, 37, 65, 41);
      line(65, 41, 73, 33);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WritingPainter oldDelegate) =>
      oldDelegate.action != action ||
      oldDelegate.ink != ink ||
      oldDelegate.paper != paper;
}
