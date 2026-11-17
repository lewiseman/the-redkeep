import 'package:flutter/material.dart';

import '../../assets/presentation/local_artwork.dart';

/// The small label above a thought: quick, text-only writing in the diary.
class DiaryThoughtMark extends StatelessWidget {
  const DiaryThoughtMark({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const LocalArtwork(
            assetKey: 'navigation.flow.inactive',
            dimension: 22,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text('THOUGHT', style: style)),
        ],
      ),
    );
  }
}
