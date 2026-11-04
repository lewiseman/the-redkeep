import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/diary_photo_question_store.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/diary_history_contract.dart';
import 'package:redkeep/features/diary/domain/diary_history_day.dart';
import 'package:redkeep/features/diary/domain/diary_photo_question_contract.dart';
import 'package:redkeep/features/voice/application/diary_conversation.dart';
import 'package:redkeep/features/voice/application/talk_session.dart';

import '../../support/fake_ai.dart';
import 'talk_session_test.dart' show FakeMic, FakeVoice;

class _Loopback extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('unchanged computer accepts photo, conversation, history, and live talk contracts over pinned signed transport', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final peer = await Process.start('node', [
        'test/support/companion_media_peer.cjs',
      ]);
      final errors = StringBuffer();
      peer.stderr.transform(utf8.decoder).listen(errors.write);
      final lines = StreamIterator(
        peer.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      addTearDown(() async {
        peer.stdin.writeln('quit');
        await peer.stdin.flush();
        await peer.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            peer.kill();
            return -1;
          },
        );
        await lines.cancel();
      });
      expect(
        await lines.moveNext().timeout(const Duration(seconds: 10)),
        isTrue,
        reason: errors.toString(),
      );
      final computer = TrustedComputer.fromJson(
        jsonDecode(lines.current) as Map<String, dynamic>,
      );
      final transport = PinnedCompanionTransport();
      addTearDown(transport.close);
      final status = await CompanionClient(transport)
          .authenticated(computer, 'GET', '/v1/status');
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: () => DateTime.now());
      final dir = await Directory.systemTemp.createTemp(
        'redkeep-media-contract-',
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          diaryRepositoryProvider.overrideWithValue(repo),
          protectedAiTasksProvider.overrideWithValue(MemoryAiTasks()),
          companionTransportProvider.overrideWithValue(transport),
          companionControllerProvider.overrideWith(
            () => TestConnection(
              CompanionState(
                phase: CompanionPhase.connected,
                computers: [computer],
                selectedId: computer.id,
                status: status,
              ),
            ),
          ),
          diaryPhotoQuestionStoreProvider.overrideWithValue(
            DiaryPhotoQuestionStore(
              db,
              supportDirectory: () => Future.value(dir),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
        await dir.delete(recursive: true);
      });
      final jobs = container.read(aiJobsProvider.notifier);
      final picture = ui.PictureRecorder();
      Canvas(picture).drawColor(Colors.orange, BlendMode.src);
      final drawing = picture.endRecording();
      final image = await drawing.toImage(32, 24);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      drawing.dispose();
      await jobs.startDiaryPhotoQuestions(
        date: CivilDate.fromComponents(DateTime.now()).key,
        photoSha: await hexHash(bytes),
        photo: bytes,
        caption: 'My synthetic orange square',
      );
      var job = container.read(aiJobsProvider).job;
      expect(
        job?.phase,
        'completed',
        reason: container.read(aiJobsProvider).message,
      );
      expect(DiaryPhotoQuestions.parse(job!.text!).groups.length, 3);
      await jobs.clear();
      final turns = [
        {'speaker': 'user', 'text': 'I planted a garden.'},
      ];
      final entry = await repo.saveConversation(
        id: 'e' * 32,
        date: CivilDate.fromComponents(DateTime.now()),
        conversation: DiaryAiConversation(
          turns: turns,
          createdAt: DateTime.now(),
        ),
        expectedRevision: 0,
      );
      await jobs.start(
        AiOperation.conversation,
        entry.id,
        jsonEncode({'action': 'draft', 'turns': turns}),
        jsonEncode({
          'id': entry.id,
          'revision': entry.revision,
          'turns': turns,
        }),
      );
      job = container.read(aiJobsProvider).job;
      expect(
        job?.text,
        'I planted a garden.',
        reason: container.read(aiJobsProvider).message,
      );
      await jobs.clear();
      final saved = await repo.save(
        id: entry.id,
        date: entry.date,
        text: const DiaryText(body: 'I planted a garden.'),
        expectedRevision: entry.revision,
      );
      final selection = DiaryHistorySelection.select(
        question: 'What did I plant?',
        today: DateTime.now(),
        days: [
          DiaryHistoryDay(entry.date.key, [saved]),
        ],
      );
      await jobs.start(
        AiOperation.history,
        'history:synthetic',
        selection.request(),
        selection.encode(),
      );
      job = container.read(aiJobsProvider).job;
      expect(
        job?.phase,
        'completed',
        reason: container.read(aiJobsProvider).message,
      );
      expect(
        DiaryHistoryAnswer.parse(job!.text!, selection).citations.single.uuid,
        entry.id,
      );
      await jobs.clear();
      final conversation = DiaryConversation(
        computer: () => computer,
        dateString: entry.date.key,
        writeDraft: () async => '',
        saveTurns: () async {},
      );
      final talk = TalkSession(
        conversation: conversation,
        voice: FakeVoice(),
        mic: FakeMic(),
      );
      await talk.start();
      for (var i = 0; i < 100 && talk.phase != TalkPhase.listening; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(talk.phase, TalkPhase.listening);
      await talk.done();
      for (
        var i = 0;
        i < 100 && !conversation.turns.any((t) => t['speaker'] == 'user');
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        conversation.turns.any(
          (t) => t['speaker'] == 'user' && t['text'] == 'I planted a garden.',
        ),
        isTrue,
      );
      await talk.end();
      talk.dispose();
      conversation.dispose();
    }, _Loopback());
  }, skip: !File('../../Journal/desktop/src/device-service.cjs').existsSync());
}
