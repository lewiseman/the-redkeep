import 'package:google_fonts/google_fonts_lite.dart';

abstract final class AppearanceFonts {
  static final families = List<String>.unmodifiable(
    GoogleFontsLite.fontsMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
  );

  static bool supports(String family) =>
      GoogleFontsLite.fontsMap.containsKey(family);
  static String validFamily(String family, String fallback) =>
      supports(family) ? family : fallback;
}
