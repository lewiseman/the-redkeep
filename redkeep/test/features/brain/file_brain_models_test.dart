import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/brain/data/file_brain_models.dart';
import 'package:redkeep/features/brain/data/model_download.dart';
import 'package:redkeep/features/brain/domain/brain.dart';

void main() {
  final bytes = List.generate(8192, (i) => i % 256);
  late Directory directory;
  late BrainModel model;
  late _Download download;
  late FileBrainModels files;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('brain-files-');
    model = BrainModel(
      id: 'synthetic-model',
      label: 'Synthetic',
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      url: 'https://fixture.test/model',
      capabilities: const {BrainCapability.summarize},
    );
    download = _Download(Stream.value(bytes));
    files = FileBrainModels(
      root: Directory('${directory.path}/brain-models'),
      download: download,
    );
  });
  tearDown(() => directory.delete(recursive: true));
  File target() => File('${files.root.path}/${model.id}.litertlm');
  File partial() => File('${files.root.path}/${model.id}.part');

  test(
    'verified install/progress/reopen/remove owns no media or writing',
    () async {
      final writing = File('${directory.path}/writing.sqlite');
      final media = File('${directory.path}/media.png');
      await writing.writeAsString('synthetic writing');
      await media.writeAsString('synthetic artwork');
      expect(await files.inspect(model), ModelFileState.missing);
      final progress = <int>[];
      await files.install(model, BrainCancellation(), progress.add);
      expect(progress.last, bytes.length);
      expect(await files.inspect(model), ModelFileState.available);
      final reopened = FileBrainModels(
        root: files.root,
        download: _Download(Stream.error(StateError('offline'))),
      );
      expect(await reopened.verifiedPath(model), target().path);
      expect(await partial().exists(), isFalse);
      await reopened.remove(model);
      expect(await reopened.inspect(model), ModelFileState.missing);
      expect(await writing.readAsString(), 'synthetic writing');
      expect(await media.readAsString(), 'synthetic artwork');
    },
  );

  test('missing and same-size corrupted replacements never load', () async {
    await expectLater(
      files.verifiedPath(model),
      throwsA(fails(BrainFailure.missing)),
    );
    await files.install(model, BrainCancellation(), (_) {});
    await target().writeAsBytes(List.filled(bytes.length, 9), flush: true);
    expect(await files.inspect(model), ModelFileState.corrupt);
    await expectLater(
      files.verifiedPath(model),
      throwsA(fails(BrainFailure.integrity)),
    );
    download.stream = Stream.value(bytes);
    await files.install(model, BrainCancellation(), (_) {});
    expect(await files.inspect(model), ModelFileState.available);
  });

  test(
    'orphan partial is interrupted, never adopted, and retried from zero',
    () async {
      await files.root.create();
      await partial().writeAsBytes(bytes);
      expect(await files.inspect(model), ModelFileState.interrupted);
      await expectLater(
        files.verifiedPath(model),
        throwsA(fails(BrainFailure.missing)),
      );
      await files.install(model, BrainCancellation(), (_) {});
      expect(download.opens, 1);
      expect(await files.inspect(model), ModelFileState.available);
      expect(await partial().exists(), isFalse);
    },
  );

  for (final kind in ['short', 'long', 'hash', 'network']) {
    test(
      '$kind download cannot promote partial bytes; retry recovers',
      () async {
        download.stream = switch (kind) {
          'short' => Stream.value(bytes.sublist(0, 10)),
          'long' => Stream.value([...bytes, 1]),
          'hash' => Stream.value(List.filled(bytes.length, 9)),
          _ => Stream.error(StateError('private URL')),
        };
        await expectLater(
          files.install(model, BrainCancellation(), (_) {}),
          throwsA(
            fails(
              kind == 'network'
                  ? BrainFailure.download
                  : BrainFailure.integrity,
            ),
          ),
        );
        expect(await target().exists(), isFalse);
        expect(await partial().exists(), isFalse);
        download.stream = Stream.value(bytes);
        await files.install(model, BrainCancellation(), (_) {});
        expect(await files.inspect(model), ModelFileState.available);
      },
    );
  }

  test(
    'cancels stalled download promptly, rejects overlap and removes partial',
    () async {
      final source = StreamController<List<int>>();
      download.stream = source.stream;
      final cancellation = BrainCancellation();
      final started = Completer<void>();
      final installing = files.install(
        model,
        cancellation,
        (_) => started.complete(),
      );
      final failed = expectLater(
        installing,
        throwsA(fails(BrainFailure.cancelled)),
      );
      source.add([1, 2, 3]);
      await started.future;
      await expectLater(files.remove(model), throwsA(fails(BrainFailure.busy)));
      cancellation.cancel();
      await failed.timeout(const Duration(seconds: 2));
      expect(await partial().exists(), isFalse);
      expect(await target().exists(), isFalse);
      await source.close();
    },
  );

  test(
    'rejects links and storage failures without overwriting another file',
    () async {
      final external = File('${directory.path}/preserve')
        ..writeAsStringSync('preserve');
      await files.root.create();
      await Link(target().path).create(external.path);
      await expectLater(
        files.install(model, BrainCancellation(), (_) {}),
        throwsA(fails(BrainFailure.storage)),
      );
      await expectLater(
        files.remove(model),
        throwsA(fails(BrainFailure.storage)),
      );
      expect(await external.readAsString(), 'preserve');
      final blocked = File('${directory.path}/blocked')
        ..writeAsStringSync('file');
      final unavailable = FileBrainModels(
        root: Directory(blocked.path),
        download: download,
      );
      await expectLater(
        unavailable.inspect(model),
        throwsA(fails(BrainFailure.storage)),
      );
    },
  );
  test(
    'removes only exact model runtime caches and preserves other support files',
    () async {
      final names = [
        '${model.id}.litertlm_123_${model.bytes}.xnnpack_cache',
        '${model.id}.litertlm_123_${model.bytes}_mldrift_program_cache.bin',
        '${model.id}.litertlm_123_${model.bytes}_mldrift_weight_cache.bin',
      ];
      const retained = [
        'redkeep.sqlite',
        'ledger.json',
        'unrelated.xnnpack_cache',
        'synthetic-model.litertlm_123_999.xnnpack_cache',
      ];
      for (final name in [...names, ...retained]) {
        await File('${directory.path}/$name')
            .writeAsString('preserve unless exact cache');
      }
      final owned = FileBrainModels(
        root: files.root,
        download: download,
        runtimeCacheRoot: directory,
      );
      await owned.remove(model);
      for (final name in names) {
        expect(await File('${directory.path}/$name').exists(), isFalse);
      }
      for (final name in retained) {
        expect(
          await File('${directory.path}/$name').readAsString(),
          'preserve unless exact cache',
        );
      }
    },
  );
  test(
    'total download deadline uses injected elapsed time and cleans the partial',
    () async {
      final bounded = FileBrainModels(
        root: files.root,
        download: download,
        createDownloadTimer: _ExpiredTimer.new,
      );
      await expectLater(
        bounded.install(model, BrainCancellation(), (_) {}),
        throwsA(fails(BrainFailure.download)),
      );
      expect(await partial().exists(), isFalse);
      expect(await target().exists(), isFalse);
    },
  );
}

Matcher fails(BrainFailure failure) =>
    isA<BrainException>().having((e) => e.failure, 'failure', failure);

class _Download implements ModelDownload {
  _Download(this.stream);
  Stream<List<int>> stream;
  int opens = 0;
  @override
  Stream<List<int>> open(Uri uri, BrainCancellation cancellation) {
    opens++;
    return stream;
  }
}

class _ExpiredTimer extends Stopwatch {
  @override
  Duration get elapsed => const Duration(hours: 2);
}
