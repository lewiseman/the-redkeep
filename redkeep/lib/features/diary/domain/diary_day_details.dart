/// A day's mood: exactly one emoji.
///
/// The five presets from the previous diary app keep their names, labels and
/// stored values ("happy", "calm"…), so existing rows and older synced devices
/// still read them. Any other emoji is stored as the emoji itself.
final class DiaryMood {
  const DiaryMood._(this.emoji, [this._label, this._preset]);

  static const happy = DiaryMood._('😊', 'Happy', 'happy');
  static const calm = DiaryMood._('😌', 'Calm', 'calm');
  static const excited = DiaryMood._('🤩', 'Excited', 'excited');
  static const tired = DiaryMood._('😴', 'Tired', 'tired');
  static const low = DiaryMood._('😔', 'Low', 'low');

  /// The quick choices, in display order.
  static const values = [happy, calm, excited, tired, low];

  final String emoji;
  final String? _label;
  final String? _preset;

  bool get isPreset => _preset != null;

  /// The stored and synced value: a preset's name, otherwise the emoji.
  String get name => _preset ?? emoji;

  /// A preset's word, or the emoji itself (screen readers name it).
  String get label => _label ?? emoji;

  /// "😊 Happy" for a preset, just the emoji otherwise.
  String get display => _label == null ? emoji : '$emoji $_label';

  /// A stored value (preset name or emoji) or a picked emoji; null when it is
  /// not exactly one emoji.
  static DiaryMood? tryParse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    for (final preset in values) {
      if (preset._preset == value) return preset;
    }
    return fromEmoji(value);
  }

  /// Exactly one emoji, including ZWJ, skin-tone, keycap and flag sequences.
  static DiaryMood? fromEmoji(String raw) {
    final value = raw.trim();
    if (!isSingleEmoji(value)) return null;
    final bare = value.replaceAll('\u{FE0F}', '');
    for (final preset in values) {
      if (preset.emoji.replaceAll('\u{FE0F}', '') == bare) return preset;
    }
    return DiaryMood._(value);
  }

  @override
  bool operator ==(Object other) => other is DiaryMood && other.emoji == emoji;

  @override
  int get hashCode => emoji.hashCode;

  @override
  String toString() => 'DiaryMood($name)';
}

const _emojiElement =
    r'(?:\p{Regional_Indicator}{2}'
    r'|[0-9#*]\u{FE0F}?\u{20E3}'
    r'|\p{Extended_Pictographic}\u{FE0F}?\p{Emoji_Modifier}?'
    r'(?:[\u{E0020}-\u{E007E}]+\u{E007F})?)';
final _emojiSequence = RegExp(
  '^$_emojiElement(?:\\u{200D}$_emojiElement)*\$',
  unicode: true,
);

/// Characters that make a sequence render as an emoji rather than as text.
final _emojiPresentation = RegExp(
  // The lint misreads Unicode property escapes; diary_mood_test runs this.
  // ignore: valid_regexps
  r'\p{Emoji_Presentation}|[\u{FE0F}\u{200D}\u{20E3}]|[\u{E0020}-\u{E007F}]',
  unicode: true,
);

/// Whether [value] is exactly one emoji: a single pictograph, flag or keycap,
/// optionally with a skin tone, variation selector, tags or ZWJ joins.
/// Text-style symbols on their own ("©", "♀") and anything with letters,
/// spaces or a second emoji are rejected.
bool isSingleEmoji(String value) =>
    value.isNotEmpty &&
    value.runes.length <= 16 &&
    _emojiSequence.hasMatch(value) &&
    _emojiPresentation.hasMatch(value);

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
