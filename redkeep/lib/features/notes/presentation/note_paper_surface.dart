import 'package:flutter/material.dart';

/// The shared, solid-color surface of the note and its app bar.
class NotePaperSurface extends StatelessWidget {
  const NotePaperSurface({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: color, child: const SizedBox.expand());
}
