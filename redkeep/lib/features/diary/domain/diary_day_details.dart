/// The manual mood choices from the previous diary app.
enum DiaryMood {
  happy('Happy', '😊'),
  calm('Calm', '😌'),
  excited('Excited', '🤩'),
  tired('Tired', '😴'),
  low('Low', '😔');

  const DiaryMood(this.label, this.emoji);
  final String label;
  final String emoji;

  static DiaryMood? tryParse(String? name) =>
      values.where((mood) => mood.name == name).firstOrNull;
}

/// Normalize manual themes without silently truncating the user's choices.
List<String> normalizeDiaryThemes(Iterable<String> themes) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in themes) {
    final theme = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (theme.isEmpty) continue;
    if (theme.runes.length > 40 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(theme) ||
        theme.runes.any((r) => r >= 0xd800 && r <= 0xdfff)) {
      throw const FormatException('Each theme must be at most 40 characters.');
    }
    if (seen.add(theme.toLowerCase())) result.add(theme);
  }
  if (result.length > 3) {
    throw const FormatException('Choose up to three themes.');
  }
  return List.unmodifiable(result);
}
