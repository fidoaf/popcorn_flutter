import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase authentication and exposes the current sign-in state.
///
/// Google OAuth is the only supported sign-in method. Listeners are notified
/// whenever the session changes (sign-in, sign-out, token refresh).
class AuthController extends ChangeNotifier {
  AuthController({SupabaseClient? client}) : _client = client ?? Supabase.instance.client {
    _subscription = _client.auth.onAuthStateChange.listen((_) => notifyListeners(), onError: _onAuthStreamError);
    _pendingOAuthError = _readRedirectError();
  }

  // Registered in the Supabase dashboard and in each platform's deep-link
  // configuration; ignored on web, where the current page URL is used instead.
  static const String _nativeRedirect = 'com.comacasaencaplloc.popcorn_flutter://login-callback/';

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;
  bool _isGuest = false;
  String? _pendingOAuthError;

  /// Initializes Supabase from `assets/config/app.env`. Call once during
  /// start-up, after `dotenv.load` and before creating an [AuthController].
  static Future<void> ensureInitialized() async {
    await Supabase.initialize(url: dotenv.env['supabase.url']!, publishableKey: dotenv.env['supabase.publishableKey']!);
  }

  /// The active session, or `null` when signed out.
  Session? get session => _client.auth.currentSession;

  /// Whether a debug-only guest session is active.
  bool get isGuest => _isGuest;

  /// Whether debug-only guest access is available (never in release builds).
  static bool get guestAccessAllowed => kDebugMode;

  /// Whether a user is currently signed in (real session or debug guest).
  bool get isSignedIn => _isGuest || session != null;

  /// The signed-in user, or `null` when signed out.
  User? get user => _client.auth.currentUser;

  /// The signed-in user's full display name from the identity provider, or
  /// `null` when unavailable (e.g. signed out or debug guest).
  String? get displayName {
    final metadata = user?.userMetadata;
    final name = metadata?['full_name'] ?? metadata?['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return null;
  }

  /// The signed-in user's first name, derived from [displayName], or `null`.
  String? get firstName {
    final name = displayName;
    if (name == null) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  /// URL of the signed-in user's avatar image, or `null` when unavailable.
  String? get avatarUrl {
    final metadata = user?.userMetadata;
    final url = metadata?['avatar_url'] ?? metadata?['picture'];
    if (url is String && url.trim().isNotEmpty) return url.trim();
    return null;
  }

  /// Enters a local guest session that bypasses sign-in. Only takes effect in
  /// debug builds; a no-op in release so it can never ship enabled.
  void continueAsGuest() {
    if (!guestAccessAllowed || _isGuest) return;
    _isGuest = true;
    notifyListeners();
  }

  /// Starts the Google OAuth flow. On web this redirects the current tab; on
  /// native platforms it opens an external browser and returns via the
  /// registered [_nativeRedirect] deep link.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? _webRedirect() : _nativeRedirect,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  // Current page URL without query/fragment so OAuth returns to the same origin
  // AND subpath (e.g. GitHub Pages project pages served under /popcorn_flutter/).
  static String _webRedirect() {
    final base = Uri.base;
    return '${base.origin}${base.path}';
  }

  /// Returns a human-readable description of an OAuth failure reported through
  /// the web redirect URL (e.g. `?error=access_denied&error_description=...`),
  /// or `null` when there is none. The value is returned only once so the
  /// message is surfaced a single time.
  String? consumeOAuthError() {
    final error = _pendingOAuthError;
    _pendingOAuthError = null;
    return error;
  }

  // Supabase reports auth failures (e.g. a failed OAuth redirect processed at
  // start-up) as errors on the auth state stream. Absorb them here so they do
  // not surface as unhandled zone errors, and keep the cause so the login
  // screen can explain it.
  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    if (error is AuthException) {
      _pendingOAuthError = error.message;
      notifyListeners();
    }
  }

  // On web, a failed OAuth redirect returns to the app with the error in the
  // query string (and occasionally the URL fragment). Prefer the human-readable
  // description, falling back to the error code.
  static String? _readRedirectError() {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    final params = <String, String>{...uri.queryParameters, ..._fragmentParams(uri)};
    if (!params.containsKey('error') && !params.containsKey('error_description')) return null;
    final description = params['error_description'];
    if (description != null && description.isNotEmpty) return description;
    return params['error'];
  }

  static Map<String, String> _fragmentParams(Uri uri) {
    final fragment = uri.fragment;
    if (!fragment.contains('=')) return const {};
    final query = fragment.contains('?') ? fragment.split('?').last : fragment;
    try {
      return Uri.splitQueryString(query);
    } catch (_) {
      return const {};
    }
  }

  /// Signs the current user out.
  Future<void> signOut() {
    _isGuest = false;
    notifyListeners();
    return _client.auth.signOut();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
