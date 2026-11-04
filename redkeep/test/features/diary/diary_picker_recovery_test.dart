import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:redkeep/features/diary/data/diary_picker_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('lost picker results stay bound to their diary address and are retrieved once', () async {
    var calls = 0;
    final recovery = DiaryPickerRecovery(
      android: true,
      retrieve: () async {
        calls++;
        return LostDataResponse(files: [XFile('/synthetic/photo.png')]);
      },
    );
    await recovery.begin('2026-11-04', 'a' * 32);
    final together = await Future.wait([
      recovery.recover(),
      recovery.recover(),
    ]);
    expect(calls, 1);
    expect(together.first!['id'], 'a' * 32);
    expect(await recovery.take('2026-11-03', 'b' * 32), isNull);
    expect(
      (await recovery.take('2026-11-04', 'a' * 32))!.single.path,
      '/synthetic/photo.png',
    );
    await recovery.clear();
    expect(await recovery.read(), isNull);
  });
  test(
    'reset fences a late picker result without recreating its marker',
    () async {
      final pending = Completer<LostDataResponse>();
      final recovery = DiaryPickerRecovery(
        android: true,
        retrieve: () => pending.future,
      );
      await recovery.begin('2026-11-04', 'a' * 32);
      final working = recovery.recover();
      await pumpEventQueue();
      await recovery.reset();
      pending.complete(
        LostDataResponse(files: [XFile('/synthetic/photo.png')]),
      );
      expect(await working, isNull);
      expect(await DiaryPickerRecovery().read(), isNull);
    },
  );
}
