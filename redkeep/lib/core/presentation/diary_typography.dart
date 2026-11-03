import 'package:flutter/material.dart';

@immutable
class DiaryTypography extends ThemeExtension<DiaryTypography> {
  const DiaryTypography({
    this.title = const TextStyle(
      fontFamily: 'Caveat',
      fontSize: 35,
      height: 1.16,
      fontWeight: FontWeight.w500,
    ),
    this.body = const TextStyle(fontFamily: 'Lora', fontSize: 17, height: 1.75),
  });

  final TextStyle title, body;

  static DiaryTypography of(BuildContext context) =>
      Theme.of(context).extension<DiaryTypography>() ?? const DiaryTypography();

  @override
  DiaryTypography copyWith({TextStyle? title, TextStyle? body}) =>
      DiaryTypography(title: title ?? this.title, body: body ?? this.body);

  @override
  DiaryTypography lerp(DiaryTypography? other, double t) =>
      t < .5 || other == null ? this : other;
}
