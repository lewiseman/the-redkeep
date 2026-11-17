import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../../auth/sync_auth.dart';
import '../../auth/sync_account_binding.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  final Future<Map<String, String>> Function() _getHeaders;
  final http.Client _inner;

  AuthenticatedHttpClient(this._getHeaders, {http.Client? inner})
    : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _getHeaders().timeout(const Duration(seconds: 30));
    request.headers.addAll(headers);
    // Generous: a resumable upload chunk is sent before headers return.
    final response = await _inner
        .send(request)
        .timeout(const Duration(minutes: 2));
    return http.StreamedResponse(
      response.stream.timeout(const Duration(seconds: 45)),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class GoogleAuthService implements SyncAuth {
  /// Injected via --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const String environmentServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Injected via --dart-define=GOOGLE_CLIENT_ID=... (optional)
  static const String environmentClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const defaultBackendId = 'google_drive';

  /// The Drive scope used by backups: the app-private folder only.
  static const List<String> defaultScopes = [
    'email',
    drive.DriveApi.driveAppdataScope,
  ];

  final String serverClientId;
  final String clientId;
  final List<String> scopes;
  final String backendId;
  final GoogleSignIn _googleSignIn;
  final SyncAccountBinding _binding;
  final http.Client Function() _clientFactory;
  GoogleSignInAccount? _currentUser;
  late final StreamSubscription<GoogleSignInAccount?> _subscription;

  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    Future<Directory> Function()? directory,
    SyncAccountBinding? accountBinding,
    http.Client Function()? clientFactory,
    this.serverClientId = environmentServerClientId,
    this.clientId = environmentClientId,
    this.scopes = defaultScopes,
    this.backendId = defaultBackendId,
  }) : _binding = accountBinding ?? SyncAccountBinding(directory: directory),
       _clientFactory = clientFactory ?? http.Client.new,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
             clientId: clientId.isNotEmpty ? clientId : null,
             scopes: scopes,
           ) {
    _subscription = _googleSignIn.onCurrentUserChanged.listen((user) {
      _currentUser = user;
    });
  }

  void dispose() => _subscription.cancel();

  @override
  SyncAccount? get currentUser => _account(_currentUser);

  static SyncAccount? _account(GoogleSignInAccount? user) => user == null
      ? null
      : SyncAccount(
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        );
  @override
  bool get isSignedIn => _currentUser != null;

  @override
  Stream<SyncAccount?> get onAuthStateChanged =>
      _googleSignIn.onCurrentUserChanged.map(_account);

  /// Attempts silent sign in on app cold launch without showing UI.
  @override
  Future<SyncAccount?> trySilentSignIn() async {
    if (Platform.isIOS && clientId.isEmpty) return null;
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return currentUser;
    } catch (e) {
      debugPrint('Silent Google Sign-In not available.');
      return null;
    }
  }

  /// Interactive sign in when user taps the "Connect Account" button.
  @override
  Future<SyncAccount?> signIn() async {
    try {
      if (Platform.isIOS && clientId.isEmpty) {
        throw StateError(
          'Google backup needs an iOS OAuth client and URL scheme configured.',
        );
      }
      if (serverClientId.isEmpty) {
        throw StateError(
          'Google backup is not configured. Set GOOGLE_SERVER_CLIENT_ID and rebuild.',
        );
      }
      _currentUser = await _googleSignIn.signIn();

      if (_currentUser != null) {
        // Android does not implement canAccessScopes. requestScopes checks
        // existing grants and asks only when Drive authorization is missing.
        if (!await _googleSignIn.requestScopes(scopes)) {
          throw StateError(
            'Google Drive access was not granted. Connect again to enable backup.',
          );
        }
      }

      return currentUser;
    } catch (e) {
      debugPrint('Google Sign-In did not complete.');
      rethrow;
    }
  }

  /// Signs out the current account.
  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// An authenticated HTTP client for Google APIs, or null when signed out.
  /// Verifies the local data belongs to this account first.
  Future<http.Client?> authenticatedClient() async {
    if (_currentUser == null) {
      await trySilentSignIn();
    }
    if (_currentUser == null) return null;

    final user = _currentUser!;
    await _binding.verify(backendId: backendId, accountId: user.id);
    return RetryClient(
      AuthenticatedHttpClient(() {
        if (_currentUser?.id != user.id) {
          throw StateError(
            'Google account changed during backup. Please retry.',
          );
        }
        return user.authHeaders;
      }, inner: _clientFactory()),
      retries: 1,
      when: (response) => response.statusCode == 401,
      delay: (_) => Duration.zero,
      onRetry: (_, _, _) => user.clearAuthCache(),
    );
  }
}
