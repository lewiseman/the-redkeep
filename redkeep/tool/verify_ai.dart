// Explicit alternate entry point. Never imported by lib/main.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redkeep/features/ai/application/local_inference_adapter.dart';
import 'package:redkeep/features/ai/data/flutter_edge_local_model.dart';
import 'package:redkeep/features/ai/domain/local_inference.dart';
import 'package:redkeep/features/brain/application/brain_executor.dart';
import 'package:redkeep/features/brain/data/file_brain_models.dart';
import 'package:redkeep/features/brain/data/model_download.dart';
import 'package:redkeep/features/brain/domain/brain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier<String>('Running synthetic M03 verification…');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (_, value, _) => SelectableText(value),
            ),
          ),
        ),
      ),
    ),
  );
  final directory = Directory(
    '${(await getApplicationSupportDirectory()).path}/m03-verification',
  );
  await directory.create(recursive: true);
  const backend = String.fromEnvironment('AI_BACKEND', defaultValue: 'cpu');
  final settings = InferenceSettings(
    backend: switch (backend) {
      'cpu' => InferenceBackend.cpu,
      'gpu' => InferenceBackend.gpu,
      _ => throw ArgumentError('AI_BACKEND must be cpu or gpu'),
    },
  );
  final report = <String, Object?>{
    'platform': Platform.operatingSystem,
    'os': Platform.operatingSystemVersion,
    'mode':
        '${kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug'} qualification; synthetic text only',
    'core': '2.5.5',
    'engine': '1.19.1',
    'native': 'native-v0.18.0-h',
    'repository': const String.fromEnvironment('MODEL_REPOSITORY'),
    'revision': const String.fromEnvironment('MODEL_REVISION'),
    'filename': const String.fromEnvironment('MODEL_FILENAME'),
    'license': const String.fromEnvironment('MODEL_LICENSE'),
    'settings': {
      'requestedBackend': backend,
      'fallback': false,
      'contextTokens': settings.contextTokens,
      'maxOutputTokens': settings.outputTokens,
      'temperature': settings.temperature,
      'topK': settings.topK,
      'topP': settings.topP,
      'seed': settings.seed,
      'thinking': false,
      'systemInstruction': 'Follow the instruction. Answer briefly.',
      'activationType': 'bundle/runtime default',
    },
  };
  final cases = <Map<String, Object?>>[];
  report['cases'] = cases;
  Future<void> persist() async {
    await File('${directory.path}/report-$backend.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  }

  LocalInferenceAdapter? adapter;
  Future<void> record(
    String name,
    Future<Map<String, Object?>> Function() body,
  ) async {
    status.value = 'M03: $name';
    report['inProgress'] = name;
    await persist();
    final timer = Stopwatch()..start();
    try {
      cases.add({
        'name': name,
        ...await body(),
        'passed': true,
        'elapsedMs': timer.elapsedMilliseconds,
      });
    } catch (error) {
      cases.add({
        'name': name,
        'passed': false,
        'error': error.toString(),
        'elapsedMs': timer.elapsedMilliseconds,
      });
      rethrow;
    } finally {
      report.remove('inProgress');
      await persist();
    }
  }

  try {
    const configuredPath = String.fromEnvironment('MODEL_PATH');
    const filename = String.fromEnvironment('MODEL_FILENAME');
    const verifyBrain = bool.fromEnvironment('VERIFY_BRAIN');
    final path = configuredPath.isEmpty
        ? '${directory.path}/${verifyBrain ? '${qualifiedBrainModel.id}.litertlm' : filename}'
        : configuredPath;
    await record('artifact_integrity', () async {
      const expected = String.fromEnvironment('MODEL_SHA256');
      const bytes = String.fromEnvironment('MODEL_BYTES');
      if (expected.length != 64 || filename.isEmpty) {
        throw StateError(
          'Pass --dart-define-from-file=tool/ai/qwen3-0.6b.json',
        );
      }
      final file = File(path);
      final size = await file.length();
      final digest = (await sha256.bind(file.openRead()).first).toString();
      if (size != int.parse(bytes) || digest != expected) {
        throw StateError('Artifact integrity failed');
      }
      return {'bytes': size, 'sha256': digest};
    });
    for (final invalid in ['missing', 'corrupt']) {
      await record('${invalid}_load', () async {
        final file = File('${directory.path}/$invalid.litertlm');
        if (invalid == 'corrupt') {
          await file.writeAsString('invalid synthetic model');
        }
        try {
          final unexpected = await openFlutterEdgeModel(file.path, settings);
          await unexpected.close();
          throw StateError('Invalid model unexpectedly loaded');
        } on InferenceException catch (error) {
          if (error.failure != InferenceFailure.load) rethrow;
          return {'failure': error.failure.name};
        } finally {
          if (await file.exists()) await file.delete();
        }
      });
    }
    for (var cycle = 0; cycle < 2; cycle++) {
      await record('load_$cycle', () async {
        adapter = LocalInferenceAdapter(
          await openFlutterEdgeModel(path, settings),
        );
        if (adapter!.backend != settings.backend) {
          throw StateError('Backend changed');
        }
        return {'activeBackend': adapter!.backend.name};
      });
      if (cycle == 0) {
        await record(
          'stream',
          () => measureTurn(
            adapter!,
            'Reply with just the result: 17 + 25 = ?',
            expected: '42',
          ),
        );
        await record(
          'cancel',
          () => measureTurn(
            adapter!,
            'List the integers from 1 to 100, one on each line.',
            cancel: true,
          ),
        );
        await record(
          'after_cancel',
          () => measureTurn(
            adapter!,
            'Repeat exactly: Good morning 😊 🚀',
            expected: 'Good morning',
          ),
        );
        await record(
          'repeat',
          () => measureTurn(
            adapter!,
            'Summarize in one sentence: Mira planted three oak trees. Rain helped them grow.',
            expected: 'Mira',
          ),
        );
      } else {
        await record(
          'after_reload',
          () => measureTurn(
            adapter!,
            'Reply with just the result: 17 + 25 = ?',
            expected: '42',
          ),
        );
      }
      await record('cleanup_$cycle', () async {
        final timer = Stopwatch()..start();
        await adapter!.close();
        await adapter!.close();
        adapter = null;
        return {'closeMs': timer.elapsedMilliseconds};
      });
    }
    if (verifyBrain) {
      final executor = BrainExecutor(
        files: FileBrainModels(root: directory, download: HttpModelDownload()),
        loadModel: openFlutterEdgeModel,
      );
      try {
        for (final capability in BrainCapability.values) {
          await record('brain_${capability.name}', () async {
            final chunks = <String>[];
            await executor.execute(
              model: qualifiedBrainModel,
              capability: capability,
              text: 'Mira planted a tree. She watered it each morning. New leaves appeared.',
              onChunk: chunks.add,
            );
            if (chunks.join().trim().isEmpty || executor.busy) {
              throw StateError('Brain did not finish and release resources');
            }
            return {
              'output': chunks.join(),
              'chunks': chunks.length,
              'activeBackend': 'cpu',
              'resourcesReleased': !executor.busy,
            };
          });
        }
        await record('brain_cancel', () async {
          var chunks = 0;
          try {
            await executor.execute(
              model: qualifiedBrainModel,
              capability: BrainCapability.rewrite,
              text: 'Mira planted a tree. She watered it each morning. New leaves appeared.',
              onChunk: (_) {
                if (++chunks == 1) unawaited(executor.cancel());
              },
            );
            throw StateError('Brain cancellation was not reported');
          } on BrainException catch (error) {
            if (error.failure != BrainFailure.cancelled || executor.busy) {
              rethrow;
            }
            return {
              'failure': error.failure.name,
              'chunks': chunks,
              'resourcesReleased': !executor.busy,
            };
          }
        });
      } finally {
        await executor.dispose();
      }
    }
    report['completed'] = true;
  } catch (error) {
    report['completed'] = false;
    report['error'] = error.toString();
  } finally {
    if (adapter != null) {
      try {
        await adapter!.close();
      } catch (error) {
        report['cleanupError'] = '$error';
      }
    }
    final json = const JsonEncoder.withIndent('  ').convert(report);
    await persist();
    status.value = json;
    // Synthetic output only; native logs are separate from this durable report.
    debugPrint('M03_REPORT ${directory.path}/report-$backend.json');
    debugPrint('M03_COMPLETED ${report['completed']}');
  }
}

Future<Map<String, Object?>> measureTurn(
  LocalInferenceAdapter adapter,
  String prompt, {
  bool cancel = false,
  String? expected,
}) async {
  final timer = Stopwatch()..start();
  final run = adapter.generate(prompt);
  final chunks = <String>[];
  int? firstMs;
  int? cancelMs;
  Future<void>? cancellation;
  final deadline = Timer(const Duration(seconds: 90), () {
    cancellation ??= run.cancel();
  });
  try {
    await for (final chunk in run.chunks) {
      if (chunk.isEmpty) continue;
      firstMs ??= timer.elapsedMilliseconds;
      chunks.add(chunk);
      if (cancel && cancellation == null) {
        cancelMs = timer.elapsedMilliseconds;
        cancellation = run.cancel();
      }
    }
    await run.done;
    if (cancellation != null) await cancellation;
    if (firstMs == null ||
        (cancel && !run.cancelled) ||
        (!cancel && run.cancelled)) {
      throw StateError('No output, failed cancellation, or timed out');
    }
    final output = chunks.join();
    return {
      'prompt': prompt,
      'output': output,
      'chunks': chunks.length,
      'firstChunkMs': firstMs,
      'totalMs': timer.elapsedMilliseconds,
      'cancelled': run.cancelled,
      if (cancelMs != null)
        'cancelToCleanupMs': timer.elapsedMilliseconds - cancelMs,
      if (expected != null) 'qualityKeywordMatched': output.contains(expected),
    };
  } finally {
    deadline.cancel();
    await run.cancel();
  }
}
