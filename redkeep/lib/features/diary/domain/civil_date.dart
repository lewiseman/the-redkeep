/// A Gregorian calendar date, never an instant. No timezone conversion is used
/// when reading a stored key or choosing another day.
class CivilDate implements Comparable<CivilDate> {
  const CivilDate._(this.year, this.month, this.day);
  factory CivilDate(int year, int month, int day) {
    final value = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        value.year != year ||
        value.month != month ||
        value.day != day) {
      throw const FormatException('Invalid civil date');
    }
    return CivilDate._(year, month, day);
  }
  factory CivilDate.fromComponents(DateTime value) =>
      CivilDate(value.year, value.month, value.day);
  static CivilDate? tryParse(String key) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
    try {
      return CivilDate(
        int.parse(key.substring(0, 4)),
        int.parse(key.substring(5, 7)),
        int.parse(key.substring(8, 10)),
      );
    } on FormatException {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;
  String get key =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  CivilDate? shift(int days) {
    final next = DateTime.utc(year, month, day + days);
    return next.year < 1 || next.year > 9999
        ? null
        : CivilDate.fromComponents(next);
  }

  int get weekday => DateTime.utc(year, month, day).weekday;
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;
  @override
  int compareTo(CivilDate other) => key.compareTo(other.key);
  @override
  bool operator ==(Object other) => other is CivilDate && key == other.key;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() => key;
}
