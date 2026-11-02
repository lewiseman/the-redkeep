import 'package:flutter/material.dart';

/// Scroll the actions with the content when large text and the keyboard leave
/// too little height for an AlertDialog's fixed action area.
class NoteActionDialog extends StatelessWidget {
  const NoteActionDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle(
            style: Theme.of(context).textTheme.headlineSmall!,
            child: title,
          ),
          const SizedBox(height: 16),
          content,
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    ),
  );
}
