import 'dart:io';

import 'backup_storage.dart';

enum BackupInterval {
  daily(Duration(days: 1)),
  weekly(Duration(days: 7)),
  monthly(Duration(days: 30)),

  /// Only when the user taps "Back up now".
  manual(null);

  final Duration? period;
  const BackupInterval(this.period);
}

class BackupSettings {
  final BackupInterval interval;

  /// Allow scheduled backups on metered (mobile) networks.
  final bool allowCellular;
  const BackupSettings({
    this.interval = BackupInterval.daily,
    this.allowCellular = false,
  });

  BackupSettings copyWith({BackupInterval? interval, bool? allowCellular}) =>
      BackupSettings(
        interval: interval ?? this.interval,
        allowCellular: allowCellular ?? this.allowCellular,
      );

  /// Whether a scheduled backup should run now. Two hours of slack keep a
  /// daily 02:00 job from slipping a day when the previous run was late.
  bool isDue(DateTime? lastSuccess, DateTime now) {
    final period = interval.period;
    if (period == null) return false;
    if (lastSuccess == null) return true;
    return now.difference(lastSuccess) >= period - const Duration(hours: 2);
  }

  Map<String, Object?> toJson() => {
    'interval': interval.name,
    'allow_cellular': allowCellular,
  };

  static BackupSettings fromJson(Map<String, dynamic>? json) {
    final name = json?['interval'];
    return BackupSettings(
      interval: BackupInterval.values.asNameMap()[name] ?? BackupInterval.daily,
      allowCellular: json?['allow_cellular'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BackupSettings &&
      other.interval == interval &&
      other.allowCellular == allowCellular;
  @override
  int get hashCode => Object.hash(interval, allowCellular);
}

/// Settings live in their own file, written only from the UI, so a running
/// background job never overwrites a change the user just made.
class BackupSettingsStore {
  final File file;
  BackupSettingsStore(this.file);
  Future<BackupSettings> read() async =>
      BackupSettings.fromJson(await readJsonFile(file));
  Future<void> write(BackupSettings settings) =>
      writeJsonFile(file, settings.toJson());
}
