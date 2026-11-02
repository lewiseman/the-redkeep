enum AppTheme { system, light, dark }

class AppearancePreferences {
  const AppearancePreferences({
    this.theme = AppTheme.system,
    this.reduceMotion = false,
    this.simplerEffects = false,
  });

  final AppTheme theme;
  final bool reduceMotion;
  final bool simplerEffects;

  AppearancePreferences copyWith({
    AppTheme? theme,
    bool? reduceMotion,
    bool? simplerEffects,
  }) => AppearancePreferences(
    theme: theme ?? this.theme,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    simplerEffects: simplerEffects ?? this.simplerEffects,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearancePreferences &&
      theme == other.theme &&
      reduceMotion == other.reduceMotion &&
      simplerEffects == other.simplerEffects;

  @override
  int get hashCode => Object.hash(theme, reduceMotion, simplerEffects);
}
