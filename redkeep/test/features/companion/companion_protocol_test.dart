import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';

void main() {
  Map<String, dynamic> code() => {
    'v': 1,
    'id': '12345678-1234-1234-1234-123456789abc',
    'name': 'Desktop',
    'pin': 'a' * 64,
    'secret': 'b' * 43,
    'endpoints': ['https://192.168.1.10:47921'],
    'expires': 101000,
  };
  test('pairing validates expiry, version, local endpoints and credential-bearing URLs', () {
    final time = DateTime.fromMillisecondsSinceEpoch(100000);
    expect(
      PairingCode.parse(jsonEncode(code()), now: time).endpoints.single.host,
      '192.168.1.10',
    );
    for (final endpoint in [
      'http://192.168.1.10:47921',
      'https://example.com',
      'https://user:pass@192.168.1.10',
      'https://192.168.1.10/path',
      'https://192.168.1.10?secret=1',
      'https://8.8.8.8',
    ]) {
      expect(
        () => PairingCode.parse(
          jsonEncode({
            ...code(),
            'endpoints': [endpoint],
          }),
          now: time,
        ),
        throwsA(isA<CompanionFailure>()),
      );
    }
    expect(
      () => PairingCode.parse(jsonEncode({...code(), 'v': 2}), now: time),
      throwsA(
        isA<CompanionFailure>().having(
          (e) => e.code,
          'code',
          'INCOMPATIBLE_VERSION',
        ),
      ),
    );
    expect(
      () => PairingCode.parse(
        jsonEncode({...code(), 'expires': 100000}),
        now: time,
      ),
      throwsA(
        isA<CompanionFailure>().having(
          (e) => e.code,
          'code',
          'PAIRING_EXPIRED',
        ),
      ),
    );
  });

  test(
    'pinned TLS verifies identity before sending any HTTP credentials',
    () async {
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/companion-cert.pem')
        ..usePrivateKey('test/fixtures/companion-key.pem');
      final pem = await File('test/fixtures/companion-cert.pem').readAsString();
      final der = base64Decode(
        pem.replaceAll(RegExp(r'-----[^-]+-----|\s'), ''),
      );
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      var requests = 0;
      final subscription = server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'v': 1, 'id': 'synthetic'}));
        await request.response.close();
      });
      final transport = PinnedCompanionTransport();
      HttpOverrides.global = _RealHttp();
      addTearDown(() => HttpOverrides.global = null);
      addTearDown(() async {
        transport.close();
        await server.close(force: true);
        await subscription.cancel();
      });
      final endpoint = Uri.parse('https://127.0.0.1:${server.port}');
      await expectLater(
        transport.request(
          endpoint,
          '0' * 64,
          'GET',
          '/v1/info',
          headers: {'secret': 'synthetic-only'},
        ),
        throwsA(
          isA<CompanionFailure>().having(
            (e) => e.code,
            'identity',
            'IDENTITY_CHANGED',
          ),
        ),
      );
      expect(requests, 0);
      final result = await transport.request(
        endpoint,
        await hexHash(der),
        'GET',
        '/v1/info',
      );
      expect(result['id'], 'synthetic');
      expect(requests, 1);
    },
  );
  test('challenge authentication signs the exact method, route and UTF-8 body digest', () async {
    final key = await Ed25519().newKeyPairFromSeed(List.filled(32, 1));
    final public = await key.extractPublicKey();
    final computer = TrustedComputer(
      id: 'synthetic',
      name: 'Synthetic',
      pin: 'a' * 64,
      endpoint: Uri.parse('https://127.0.0.1:47921'),
      seed: base64Encode(List.filled(32, 1)),
      publicKey: base64Encode(public.bytes),
      deviceId: 'b' * 32,
    );
    final peer = _SignaturePeer();
    await CompanionClient(peer).authenticated(
      computer,
      'POST',
      '/v1/jobs',
      body: {'prompt': 'Synthetic 🌿 中文'},
    );
    final canonical =
        'v1\n${computer.deviceId}\nPOST\n/v1/jobs\n${peer.nonce}\n${await hexHash(utf8.encode(jsonEncode(peer.body)))}';
    expect(
      await Ed25519().verify(
        utf8.encode(canonical),
        signature: Signature(
          base64Decode(peer.headers['x-journal-signature']!),
          publicKey: public,
        ),
      ),
      isTrue,
    );
  });
}

class _SignaturePeer implements CompanionTransport {
  final nonce = base64UrlEncode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  Map<String, String> headers = {};
  Map<String, dynamic>? body;
  @override
  Future<Map<String, dynamic>> request(
    Uri endpoint,
    String pin,
    String method,
    String route, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (route == '/v1/challenge') return {'nonce': nonce};
    this.headers = headers;
    this.body = body;
    return {'ok': true};
  }

  @override
  void close() {}
}

class _RealHttp extends HttpOverrides {}
