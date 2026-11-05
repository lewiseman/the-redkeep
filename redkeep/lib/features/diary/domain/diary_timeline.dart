import 'diary_period.dart';

/// Ordinary days are implicit; only saved special pages need an index.
class DiaryTimeline {
  DiaryTimeline({required this.today, Iterable<DiaryPeriod> saved = const []})
    : specials =
          (saved.where((p) => !p.isDay && p.hasStarted(today)).toSet().toList()
            ..sort());

  final DateTime today;
  final List<DiaryPeriod> specials;

  DiaryPeriod? neighbor(DiaryPeriod selected, int direction) {
    assert(direction == -1 || direction == 1);
    final day = DiaryPeriod.day(selected.start);
    DiaryPeriod? candidate = direction > 0 && !selected.isDay
        ? day
        : selected.shift(direction);
    if (candidate != null && !candidate.hasStarted(today)) candidate = null;
    // Find the insertion point without walking or allocating ordinary days.
    var low = 0, high = specials.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (specials[mid].compareTo(selected) < (direction > 0 ? 1 : 0)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final index = direction > 0 ? low : low - 1;
    if (index >= 0 && index < specials.length) {
      final special = specials[index];
      if (candidate == null || special.compareTo(candidate) * direction < 0) {
        candidate = special;
      }
    }
    return candidate;
  }

  DiaryPeriod? offset(DiaryPeriod selected, int steps) {
    DiaryPeriod? value = selected;
    for (var i = 0; i < steps.abs() && value != null; i++) {
      value = neighbor(value, steps.sign);
    }
    return value;
  }
}
