import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/watch_title.dart';
import 'watch_widgets.dart';

/// Evenings worth offering first, at 8pm local time.
List<(String, DateTime)> quickNights(DateTime now) {
  DateTime eight(int days) {
    final day = now.add(Duration(days: days));
    return DateTime(day.year, day.month, day.day, 20);
  }

  final tonight = eight(0).difference(now) > const Duration(minutes: 30);
  var toSaturday = (DateTime.saturday - now.weekday) % 7;
  // Saturday is offered when it is not already tonight or tomorrow.
  if (toSaturday == 0 && !tonight) toSaturday = 7;
  return [
    if (tonight) ('Tonight', eight(0)),
    ('Tomorrow night', eight(1)),
    if (toSaturday > 1) ('Saturday night', eight(toSaturday)),
  ];
}

/// Picks a time and plans the night. Returns whether one was planned.
Future<bool> planNightFlow(
  BuildContext context,
  WidgetRef ref,
  WatchTitle title,
) async {
  final now = ref.read(watchClockProvider)();
  final format = DateFormat('EEE d MMM, HH:mm');
  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        ListTile(
          title: Text(
            'Watch ${title.title}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        for (final (label, at) in quickNights(now))
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(label),
            subtitle: Text(format.format(at)),
            onTap: () => Navigator.pop(sheet, at),
          ),
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: const Text('Pick a time…'),
          onTap: () async {
            final day = await showDatePicker(
              context: sheet,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 60)),
              initialDate: now,
            );
            if (day == null || !sheet.mounted) return;
            final time = await showTimePicker(
              context: sheet,
              initialTime: const TimeOfDay(hour: 20, minute: 0),
            );
            if (time == null || !sheet.mounted) return;
            Navigator.pop(
              sheet,
              DateTime(day.year, day.month, day.day, time.hour, time.minute),
            );
          },
        ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return false;
  final done = await runWatchAction(context, () async {
    await ref.read(watchNightsProvider).planNight(title, picked);
    return true;
  });
  if (done == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Planned for ${format.format(picked)}.')),
    );
  }
  return done == true;
}

/// Loved it, fine, or never again.
Future<void> checkInFlow(
  BuildContext context,
  WidgetRef ref,
  WatchTitle title,
) async {
  final outcome = await showModalBottomSheet<NightOutcome>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'How was ${title.title}?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final o in NightOutcome.values)
            ListTile(
              leading: Icon(switch (o) {
                NightOutcome.loved => Icons.favorite,
                NightOutcome.fine => Icons.thumbs_up_down_outlined,
                NightOutcome.neverAgain => Icons.heart_broken_outlined,
              }),
              title: Text(o.label),
              onTap: () => Navigator.pop(sheet, o),
            ),
        ],
      ),
    ),
  );
  if (outcome == null || !context.mounted) return;
  await runWatchAction(
    context,
    () => ref.read(watchNightsProvider).checkIn(title, outcome),
  );
}
