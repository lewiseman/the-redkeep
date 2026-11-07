import 'package:flutter/material.dart';

/// Asks before a tick on a website changes the note's own checklist.
Future<({bool allow, bool remember})> confirmWebsiteCheck(
  BuildContext context,
  String item,
  bool done,
) async {
  if (!context.mounted) return (allow: false, remember: false);
  var remember = false;
  final allow = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, update) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          key: const ValueKey('note-website-check-confirm'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              done
                  ? 'Tick it in your note too?'
                  : 'Untick it in your note too?',
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              done
                  ? '“$item” will be marked done in the note text.'
                  : '“$item” will be marked not done in the note text.',
            ),
            CheckboxListTile(
              key: const ValueKey('note-website-check-remember'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: remember,
              onChanged: (v) => update(() => remember = v ?? false),
              title: const Text('Always update the note from this website'),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(sheet, false),
                  child: const Text('Only on the page'),
                ),
                FilledButton(
                  key: const ValueKey('note-website-check-allow'),
                  onPressed: () => Navigator.pop(sheet, true),
                  child: const Text('Update note'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return (allow: allow == true, remember: allow == true && remember);
}
