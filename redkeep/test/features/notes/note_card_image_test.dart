import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/domain/note_collection_entry.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/presentation/note_card.dart';
import 'package:redkeep/features/notes/presentation/note_scene.dart';

void main() {
  testWidgets('a painted backdrop is drawn without nesting ResizeImage', (
    tester,
  ) async {
    const key = 'note_media/painted.png';
    // The background provider hands out images already wrapped like this.
    final image = ResizeImage(
      MemoryImage(Uint8List.fromList([0])),
      width: 2048,
      height: 2048,
      policy: ResizeImagePolicy.fit,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteBackgroundImageProvider(key).overrideWith((_) async => image),
        ],
        child: MaterialApp(
          builder: (context, child) => RenderingPolicyScope(
            policy: RenderingPolicy(
              osReducedMotion: false,
              preferences: const AppearancePreferences(),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: NoteCard(
                index: 0,
                onTap: () {},
                entry: NoteCollectionEntry(
                  id: 'n',
                  title: 'Garden',
                  excerpt: 'Plant tomatoes',
                  updatedAt: DateTime.utc(2026),
                  pinned: false,
                  details: const NoteDetails(
                    background: {
                      'type': 'sage',
                      'image': key,
                      'image_source': 'local',
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Flutter rejects a ResizeImage inside another, and the card's error
    // builder would quietly show plain paper instead.
    final drawn = tester.widget<Image>(find.byType(Image)).image;
    expect(drawn, isA<ResizeImage>());
    expect((drawn as ResizeImage).imageProvider, isNot(isA<ResizeImage>()));
    expect(drawn.width, 720);

    // The paper over it thins toward the bottom so the artwork shows.
    final wash = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .single;
    expect(wash.colors.first.a, greaterThan(wash.colors.last.a));
    expect(wash.colors.last.a, lessThanOrEqualTo(.35));
  });
}
