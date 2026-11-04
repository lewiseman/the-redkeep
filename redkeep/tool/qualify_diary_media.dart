// Isolated Android qualification entry point. Build only in a temporary copy
// with a distinct application ID; never install over a person's Redkeep app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/data/diary_photo_stories.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/voice/data/pcm_recorder.dart';
import 'package:redkeep/features/voice/data/voice_store.dart';
import 'package:redkeep/features/voice/data/voice_connection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _results = <String, Object?>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    _results['utc'] = DateTime.now().toUtc().toIso8601String();
    final recorder = PcmRecorder();
    AppDatabase? db;
    try {
      final store = VoiceStore();
      final id = 'qualify-audio-11111111';
      final file = File('${(await store.directory()).path}/$id.pcm');
      if (await file.exists()) await file.delete();
      if (await PcmRecorder.methods.invokeMethod<bool>('permission') != true) {
        throw StateError('Permission denied');
      }
      var chunks = 0, bytes = 0;
      final captured = BytesBuilder(copy: false);
      await recorder.start(
        path: file.path,
        onData: (data) {
          chunks++;
          bytes += data.length;
          captured.add(data);
        },
        onStopped: () {},
        onError: (e) {
          _results['nativeError'] = e.toString();
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 750));
      await recorder.stop();
      final pcm = captured.takeBytes();
      if (chunks == 0 || bytes != await file.length() || bytes % 2 != 0) {
        throw StateError('Native PCM/file mismatch');
      }
      _results['nativePcm'] = {
        'chunks': chunks,
        'bytes': bytes,
        'fileMatchesFrames': true,
        'sampleRate': 16000,
        'channels': 1,
        'format': 's16le',
      };
      await store.save('flow', {
        'id': id,
        'created': DateTime.now().millisecondsSinceEpoch,
        'text': 'Synthetic retained text',
      });
      if ((await store.load('flow'))?['text'] != 'Synthetic retained text') {
        throw StateError('Protected round trip');
      }
      await store.consumed('flow');
      if (await file.exists() || await store.load('flow') != null) {
        throw StateError('Audio cleanup');
      }
      _results['protectedDraftAndAudioCleanup'] = true;
      db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: DateTime.now);
      final photos = DiaryPhotoStore(db: db);
      final picture = ui.PictureRecorder();
      Canvas(picture).drawColor(Colors.orange, BlendMode.src);
      final drawing = picture.endRecording();
      final image = await drawing.toImage(32, 24);
      final photo = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      drawing.dispose();
      final entry = await DiaryPhotoStories(repo, photos).save(
        dateString: CivilDate.fromComponents(DateTime.now()).key,
        newItemUuid: 'e' * 32,
        photos: [
          (
            draft: DiaryPhotoDraft(
              bytes: photo,
              sha256: await DiaryPhotoStore.digest(photo),
              sourceExtension: '.png',
            ),
            caption: 'Synthetic photo caption',
            reflections: [],
            seen: '',
          ),
        ],
      );
      if ((await DiaryPhotoStories(repo, photos).open(entry)).single.missing) {
        throw StateError('Photo copy unreadable');
      }
      await repo.deleteEntry(entry.id, entry.revision);
      await photos.reconcile();
      if (await photos.resolve(entry.photos.single.path) != null) {
        throw StateError('Removed photo was not cleaned');
      }
      _results['nativePhotoStorageAndCleanup'] = true;
      const peer = String.fromEnvironment('QUAL_COMPUTER');
      if (peer.isNotEmpty) {
        final computer = TrustedComputer.fromJson(
          jsonDecode(peer) as Map<String, dynamic>,
        );
        final voiceId =
            'qualify-voice-${DateTime.now().microsecondsSinceEpoch}';
        final socket = await connectVoice(computer, voiceId);
        final ready = Completer<void>(),
            result = Completer<Map<String, dynamic>>();
        final events = socket.listen((raw) {
          final e = jsonDecode(raw as String) as Map<String, dynamic>;
          if (e['type'] == 'ready' && !ready.isCompleted) ready.complete();
          if (e['type'] == 'job' && !result.isCompleted) {
            result.complete(Map<String, dynamic>.from(e['job'] as Map));
          }
          if (e['type'] == 'error' && !result.isCompleted) {
            result.completeError(StateError(e['message'] as String));
          }
        });
        await ready.future.timeout(const Duration(seconds: 15));
        var frames = 0;
        for (var offset = 0; offset < pcm.length; offset += 3200) {
          final end = (offset + 3200).clamp(0, pcm.length);
          final frame = Uint8List(end - offset + 4);
          ByteData.sublistView(frame).setUint32(0, frames++, Endian.big);
          frame.setRange(4, frame.length, pcm.sublist(offset, end));
          socket.add(frame);
        }
        socket.add(
          jsonEncode({
            'type': 'finish',
            'frames': frames,
            'bytes': pcm.length,
            'sha256': await hexHash(pcm),
          }),
        );
        final job = await result.future.timeout(const Duration(seconds: 20));
        if (job['accepted'] != true ||
            job['state'] != 'completed' ||
            job['id'] != voiceId ||
            job['device'] != computer.deviceId) {
          throw StateError('Voice transport failed');
        }
        final transport = PinnedCompanionTransport();
        try {
          await CompanionClient(transport)
              .authenticated(computer, 'POST', '/v1/voice/$voiceId/ack');
        } finally {
          transport.close();
        }
        _results['companionVoiceTransport'] = {
          'accepted': true,
          'acknowledged': true,
          'state': job['state'],
          'syntheticSpeech': true,
        };
        await events.cancel();
        await socket.close();
      }
      _results['passed'] = true;
    } catch (e) {
      _results['error'] = e.toString();
      _results['passed'] = false;
    } finally {
      await recorder.stop();
      await db?.close();
    }
    final json = jsonEncode(_results);
    debugPrint('REDKEEP_MEDIA_QUAL $json');
    await File(
      '${(await getApplicationSupportDirectory()).path}/media-qualification.json',
    ).writeAsString(json, flush: true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synthetic media qualification')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(const JsonEncoder.withIndent('  ').convert(_results)),
    ),
  );
}
