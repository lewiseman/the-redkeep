import 'watch_title.dart';

enum ReminderKind { matchExpiring, nightSoon, checkIn }

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.titleId,
  });

  /// Stable per title and kind, so planning again replaces it.
  final int id;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;
  final String titleId;
}

/// Pure: what the reader should be reminded of, and when.
class ReminderPlanner {
  const ReminderPlanner();

  static int idFor(String titleId, ReminderKind kind) =>
      // 28 bits of the title id leave room for the kind and stay positive.
      (int.parse(titleId.substring(0, 7), radix: 16) << 2 | kind.index) &
      0x7fffffff;

  List<PlannedReminder> plan(
    Iterable<WatchTitle> titles, {
    required DateTime now,
    Map<String, int> runtimes = const {},
  }) => [
    for (final t in titles)
      for (final r in _forTitle(t, runtimes[t.id]))
        if (r.at.isAfter(now)) r,
  ];

  List<PlannedReminder> _forTitle(WatchTitle t, int? runtime) {
    PlannedReminder make(
      ReminderKind kind,
      DateTime at,
      String title,
      String body,
    ) => PlannedReminder(
      id: idFor(t.id, kind),
      kind: kind,
      at: at,
      title: title,
      body: body,
      titleId: t.id,
    );
    if (t.matchState == MatchState.active && t.expiresAt != null) {
      return [
        make(
          ReminderKind.matchExpiring,
          t.expiresAt!.subtract(const Duration(days: 1)),
          '${t.title} is waiting',
          'Your match ends tomorrow. Plan a night or let it go.',
        ),
      ];
    }
    if (t.matchState == MatchState.dated &&
        t.nightAt != null &&
        t.outcome == null) {
      return [
        make(
          ReminderKind.nightSoon,
          t.nightAt!.subtract(const Duration(hours: 1)),
          'Watch night in an hour',
          '${t.title} at ${_time(t.nightAt!.toLocal())}.',
        ),
        make(
          ReminderKind.checkIn,
          t.nightAt!.add(Duration(minutes: (runtime ?? 120) + 15)),
          'How was ${t.title}?',
          'Tell the Watchlist how the night went.',
        ),
      ];
    }
    return const [];
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// The device's notifications. Tests use a fake.
abstract interface class WatchReminders {
  /// Replaces every scheduled Watchlist reminder with [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Asks once, the first time a night is planned.
  Future<bool> requestPermission();
}
