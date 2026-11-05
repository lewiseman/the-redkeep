import 'package:flutter/material.dart' show Color;

enum AppTheme { system, light, dark }

class AppearancePreferences {
  const AppearancePreferences({
    this.theme = AppTheme.system,
    this.accent = AppAccent.indigo,
    this.fontFamily = defaultFontFamily,
    this.diaryTitleFontFamily = defaultDiaryTitleFontFamily,
    this.diaryBodyFontFamily = defaultDiaryBodyFontFamily,
    this.reduceMotion = false,
    this.simplerEffects = false,
  });

  static const defaultFontFamily = 'Poppins';
  static const defaultDiaryTitleFontFamily = 'Caveat';
  static const defaultDiaryBodyFontFamily = 'Literata';

  final AppTheme theme;
  final AppAccent accent;
  final String fontFamily, diaryTitleFontFamily, diaryBodyFontFamily;
  final bool reduceMotion;
  final bool simplerEffects;

  AppearancePreferences copyWith({
    AppTheme? theme,
    AppAccent? accent,
    String? fontFamily,
    String? diaryTitleFontFamily,
    String? diaryBodyFontFamily,
    bool? reduceMotion,
    bool? simplerEffects,
  }) => AppearancePreferences(
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    fontFamily: fontFamily ?? this.fontFamily,
    diaryTitleFontFamily: diaryTitleFontFamily ?? this.diaryTitleFontFamily,
    diaryBodyFontFamily: diaryBodyFontFamily ?? this.diaryBodyFontFamily,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    simplerEffects: simplerEffects ?? this.simplerEffects,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearancePreferences &&
      theme == other.theme &&
      accent == other.accent &&
      fontFamily == other.fontFamily &&
      diaryTitleFontFamily == other.diaryTitleFontFamily &&
      diaryBodyFontFamily == other.diaryBodyFontFamily &&
      reduceMotion == other.reduceMotion &&
      simplerEffects == other.simplerEffects;

  @override
  int get hashCode => Object.hash(
    theme,
    accent,
    fontFamily,
    diaryTitleFontFamily,
    diaryBodyFontFamily,
    reduceMotion,
    simplerEffects,
  );
}

enum AppAccent {
  indigo(
    'Indigo',
    'The original journal ink',
    Color(0xFF161658),
    Color(0xFFB9B7FF),
  ),
  teal('Teal', 'Calm coastal greens', Color(0xFF176B65), Color(0xFF80D5CC)),
  walnut(
    'Walnut',
    'Warm leather and coffee',
    Color(0xFF795548),
    Color(0xFFD8B798),
  ),
  olive('Olive', 'Soft, earthy greens', Color(0xFF59633B), Color(0xFFC0CB8F)),
  terracotta(
    'Terracotta',
    'Sun-warmed clay',
    Color(0xFFA04F38),
    Color(0xFFF2B09C),
  ),
  plum('Plum', 'A mellow, dusky purple', Color(0xFF754B70), Color(0xFFDCB0D2));

  const AppAccent(this.label, this.description, this.seed, this.darkPrimary);

  final String label;
  final String description;
  final Color seed;
  final Color darkPrimary;

  static AppAccent fromName(Object? name) =>
      values.firstWhere((accent) => accent.name == name, orElse: () => indigo);
}
