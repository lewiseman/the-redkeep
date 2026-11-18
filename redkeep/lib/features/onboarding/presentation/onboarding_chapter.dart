import 'package:flutter/material.dart';

// Original spreads are restored by the user's visual-parity instruction.
// Accessible/current descriptions remain separate from decorative printed art.
const onboardingFeatures = [
  (
    name: 'Notes',
    artwork: 'onboarding.chapter.notes',
    scene: 'Paper note cards, a pencil and olive leaves.',
    title: 'Catch a thought.',
    detail: 'Write, organize, and revisit your notes.',
    accent: Color(0xFF517E71),
  ),
  (
    name: 'Diary',
    artwork: 'onboarding.chapter.diary',
    scene: 'A sunny diary page and coffee by a window.',
    title: 'Keep the moments.',
    detail: 'A place for ordinary days and unforgettable ones.',
    accent: Color(0xFFA46D63),
  ),
  (
    name: 'Backup',
    // Provider-neutral art: the buttons below name the sign-in provider.
    artwork: 'onboarding.chapter.backup',
    scene: 'A journal resting safely, ready to come back to you.',
    title: 'Keep your journal safe.',
    detail: 'Restore your journal from a backup, or skip and start fresh.',
    accent: Color(0xFF8265B0),
  ),
];
