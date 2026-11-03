import 'package:flutter/material.dart';

/// Counts every text/selection/composing change, including changes undone before
/// the next frame. This token is independent of recovery persistence timing.
class MaesterSelection extends StatefulWidget {
  const MaesterSelection({
    super.key,
    required this.body,
    required this.builder,
  });
  final TextEditingController body;
  final Widget Function(
    TextSelection selection,
    int version,
    int Function() currentVersion,
  )
  builder;
  @override
  State<MaesterSelection> createState() => _MaesterSelectionState();
}

class _MaesterSelectionState extends State<MaesterSelection> {
  int _version = 0;
  @override
  void initState() {
    super.initState();
    widget.body.addListener(_changed);
  }

  @override
  void didUpdateWidget(MaesterSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      oldWidget.body.removeListener(_changed);
      widget.body.addListener(_changed);
      _version++;
    }
  }

  void _changed() => setState(() => _version++);
  @override
  void dispose() {
    widget.body.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(widget.body.selection, _version, () => _version);
}

({int start, int end}) maesterRange(String body, TextSelection selection) =>
    selection.isValid && !selection.isCollapsed && selection.end <= body.length
    ? (start: selection.start, end: selection.end)
    : (start: 0, end: body.length);
