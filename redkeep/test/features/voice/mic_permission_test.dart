import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/voice/application/mic_permission.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('redkeep.test.mic');
  late List<String> calls;
  var status = 'denied';
  setUp(() {
    calls = [];
    status = 'denied';
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return call.method == 'openSettings' ? true : status;
    });
  });
  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );
  test('checking never requests recording permission; an explicit request updates status', () async {
    final permission = MicPermission(methods: channel, supported: true);
    addTearDown(permission.dispose);
    expect(await permission.check(), MicStatus.denied);
    expect(calls, ['micStatus']);
    status = 'granted';
    expect(await permission.request(), MicStatus.granted);
    expect(calls, contains('requestMic'));
  });
  test('blocked permission opens Settings and rechecks on return', () async {
    final permission = MicPermission(methods: channel, supported: true);
    addTearDown(permission.dispose);
    status = 'blocked';
    await permission.check();
    await permission.request();
    expect(calls, contains('openSettings'));
    expect(calls, isNot(contains('requestMic')));
    status = 'granted';
    expect(await permission.check(), MicStatus.granted);
  });
  test('unsupported platforms do not request the microphone', () async {
    final permission = MicPermission(methods: channel, supported: false);
    addTearDown(permission.dispose);
    expect(await permission.check(), MicStatus.unsupported);
    await permission.request();
    expect(calls, isEmpty);
  });
}
