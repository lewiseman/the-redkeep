import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/domain/note_rich_markdown.dart';

/// The note body editor: rich for the core Markdown, plain text otherwise.
Finder noteBody() => find.byKey(const ValueKey('note-body'));

/// Replaces the body as a writer would, in whichever editor is showing.
Future<void> enterNoteBody(WidgetTester tester, String text) async {
  final editor = tester.widget(noteBody());
  if (editor is QuillEditor) {
    final controller = editor.controller;
    controller.replaceText(
      0,
      controller.document.length - 1,
      text,
      TextSelection.collapsed(offset: text.length),
    );
    await tester.pump();
  } else {
    await tester.enterText(noteBody(), text);
  }
}

/// The body's Markdown as the editor currently stands.
String noteBodyText(WidgetTester tester) {
  final editor = tester.widget(noteBody());
  return editor is QuillEditor
      ? markdownFromRich(editor.controller.document.toDelta())
      : (editor as TextField).controller!.text;
}

/// The rich editor's controller (fails for a plain-text body).
QuillController richBody(WidgetTester tester) =>
    tester.widget<QuillEditor>(noteBody()).controller;
