import '../application/notes_providers.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../data/note_media_store.dart';
import '../domain/note_document.dart';
import '../domain/note_colors.dart';
import 'edit_note_page_bg.dart';

final noteBackgroundImageProvider = FutureProvider.autoDispose
    .family<ImageProvider?, String>((ref, key) async {
      File? file;
      if (key.startsWith('note_media/')) {
        file = await ref.watch(noteMediaStoreProvider).resolve(key);
      } else {
        final uri = await (await ref.watch(assetResolverProvider)).resolve(key);
        file = File.fromUri(uri);
      }
      return file == null
          ? null
          : ResizeImage(
              FileImage(file),
              width: 2048,
              height: 2048,
              policy: ResizeImagePolicy.fit,
            );
    });

class NoteScene extends ConsumerWidget {
  const NoteScene({
    super.key,
    required this.details,
    required this.seed,
    required this.child,
  });
  final NoteDetails details;
  final int seed;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NoteColors.fromBackground(
      Theme.of(context).colorScheme,
      details.background,
    );
    final key = details.background['image'] ?? details.background['asset'];
    final image = key is String
        ? ref.watch(noteBackgroundImageProvider(key)).value
        : null;
    final base = Theme.of(context);
    return EditNotepageBg(
      animate: ref.watch(notesAmbientMotionProvider),
      seed: seed,
      color: colors.background,
      image: image,
      builder: (context, opacity, header) => Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: base.colorScheme.copyWith(
            onSurface: colors.foreground,
            surfaceContainerLow: colors.background,
          ),
          textTheme: base.textTheme.apply(
            bodyColor: colors.foreground,
            displayColor: colors.foreground,
          ),
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: colors.background,
            foregroundColor: colors.foreground,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: NotePaperOpacity(opacity: opacity, child: child),
      ),
    );
  }
}

/// Shares the original painting's readable paper opacity with the folded paper.
class NotePaperOpacity extends InheritedWidget {
  const NotePaperOpacity({
    super.key,
    required this.opacity,
    required super.child,
  });
  final Animation<double> opacity;
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotePaperOpacity>()?.opacity ??
      const AlwaysStoppedAnimation(1);
  @override
  bool updateShouldNotify(NotePaperOpacity oldWidget) =>
      opacity != oldWidget.opacity;
}
