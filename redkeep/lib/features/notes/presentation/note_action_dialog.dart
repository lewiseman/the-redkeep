import 'package:flutter/material.dart';

Future<bool?> showNoteDeleteConfirmation(BuildContext context) =>
    showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => NoteActionDialog(
        title: const Text('Delete this note?'),
        content: const Text(
          'The note will move to Trash and leave saved lists and search. Its text, tags and pin stay on this device until you choose Delete forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep note'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

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
