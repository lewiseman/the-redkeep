import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync_wise/sync_wise.dart';

void main() {
  late Directory directory;
  late SyncAccountBinding binding;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync-binding-');
    binding = SyncAccountBinding(directory: () async => directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'ignores Journal account files when binding and clearing Redkeep accounts',
    () async {
      final journalBinding = File('${directory.path}/sync_account.id');
      final journalTemporary = File('${directory.path}/sync_account.id.tmp');
      await journalBinding.writeAsString('journal-owner');
      await journalTemporary.writeAsString('journal-pending');
      await binding.verify(
        backendId: 'google_drive',
        accountId: 'redkeep-owner',
      );
      expect(
        jsonDecode(
          await File('${directory.path}/sync_account.json').readAsString(),
        ),
        {'backend_id': 'google_drive', 'account_id': 'redkeep-owner'},
      );
      final temporary = File('${directory.path}/sync_account.json.tmp');
      await temporary.writeAsString('interrupted');
      await binding.clear();
      expect(
        await File('${directory.path}/sync_account.json').exists(),
        isFalse,
      );
      expect(await temporary.exists(), isFalse);
      expect(await journalBinding.readAsString(), 'journal-owner');
      expect(await journalTemporary.readAsString(), 'journal-pending');
    },
  );

  test(
    'pins both provider and account until local data is explicitly cleared',
    () async {
      await binding.verify(backendId: 'native', accountId: 'owner');
      await binding.verify(backendId: 'native', accountId: 'owner');
      await expectLater(
        binding.verify(backendId: 'other', accountId: 'owner'),
        throwsStateError,
      );
      await expectLater(
        binding.verify(backendId: 'native', accountId: 'other'),
        throwsStateError,
      );
      await binding.clear();
      await binding.verify(backendId: 'other', accountId: 'new-owner');
    },
  );
}
