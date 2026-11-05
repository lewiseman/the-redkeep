import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_curl.dart';

Future<void> warmDiaryFaces(WidgetTester tester) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    final faces = tester
        .renderObjectList<RenderDiaryCurl>(find.byType(DiaryPaperCurl))
        .toList();
    await tester.runAsync(
      () => Future.wait(faces.map((face) => face.prepareTextures())),
    );
    await tester.pump();
    if (faces.every((face) => face.debugReady)) return;
  }
  fail('Diary faces did not finish asynchronous preparation');
}
