import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/presentation/note_tag_strip.dart';

({String emoji, String name, String value}) _tag(String value) =>
    (emoji: '🏷️', name: value, value: value);

void main() {
  test('All sits in the middle with others alternating right then left', () {
    final arranged = NoteTagStrip.arrange([
      _tag(NoteTagStrip.all),
      _tag('drafts'),
      _tag('pinned'),
      _tag('trash'),
      _tag('work'),
      _tag('home'),
    ]).map((tag) => tag.value);
    expect(arranged, [
      'work',
      'pinned',
      NoteTagStrip.all,
      'drafts',
      'trash',
      'home',
    ]);
  });

  testWidgets('selected All chip is centered when the strip first loads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => RenderingPolicyScope(
          policy: RenderingPolicy(
            osReducedMotion: false,
            preferences: const AppearancePreferences(),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: NoteTagStrip(
            tags: [
              _tag(NoteTagStrip.all),
              for (var i = 0; i < 12; i++) _tag('tag $i'),
            ],
            selectedTag: NoteTagStrip.all,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final all = tester.getCenter(find.byKey(const ValueKey('notes-all')));
    expect(all.dx, moreOrLessEquals(180, epsilon: 1));
  });
}
