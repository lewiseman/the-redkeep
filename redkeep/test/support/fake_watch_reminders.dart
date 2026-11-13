import 'package:redkeep/features/watchlist/domain/reminders.dart';

/// Records what would be scheduled; never touches the device.
class FakeWatchReminders implements WatchReminders {
  List<PlannedReminder> scheduled = const [];
  int permissionRequests = 0;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    scheduled = reminders;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }
}
