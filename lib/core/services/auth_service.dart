import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result of an authentication attempt.
///
/// Use the named factories (`AuthResult.success`, `AuthResult.cancelled`,
/// `AuthResult.error`, `AuthResult.user`) to create the appropriate state.
class AuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;
  final User? user;

  const AuthResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(User user) => AuthResult._(
        isSuccess: true,
        isCancelled: false,
        user: user,
      );

  factory AuthResult.cancelled() => const AuthResult._(
        isSuccess: false,
        isCancelled: true,
      );

  factory AuthResult.error(String message) => AuthResult._(
        isSuccess: false,
        isCancelled: false,
        errorMessage: message,
      );

  factory AuthResult.user(User user) => AuthResult._(
        isSuccess: true,
        isCancelled: false,
        user: user,
      );

  bool get isError => errorMessage != null;
}

/// Singleton authentication service that wraps Firebase Auth and exposes
/// a [ChangeNotifier] interface for UI consumers.
class AuthService extends ChangeNotifier {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  factory AuthService() => _instance;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  StreamSubscription<User?>? _authSub;
  User? _currentUser;
  bool _initialized = false;

  User? get currentUser => _currentUser;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isAnonymous => _currentUser?.isAnonymous ?? false;

  bool get isLoggedIn =>
      _currentUser != null && !(_currentUser?.isAnonymous ?? true);

  String? get userId => _currentUser?.uid;

  String? get displayName => _currentUser?.displayName;

  String? get email => _currentUser?.email;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Subscribes to auth state changes and ensures we always have a user
  /// (anonymous by default so local data can be linked later).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _authSub?.cancel();
    _authSub = _firebaseAuth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });

    _currentUser = _firebaseAuth.currentUser;
    if (_currentUser == null) {
      try {
        final cred = await _firebaseAuth.signInAnonymously();
        _currentUser = cred.user;
        notifyListeners();
      } catch (e) {
        debugPrint('AuthService: anonymous sign-in failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final anonUser = _firebaseAuth.currentUser;

      try {
        if (anonUser != null && anonUser.isAnonymous) {
          // Link anon account to Google so we keep the UID + local data.
          final UserCredential linked =
              await anonUser.linkWithCredential(credential);
          _currentUser = linked.user;
          notifyListeners();
          return AuthResult.success(linked.user!);
        } else {
          final UserCredential result =
              await _firebaseAuth.signInWithCredential(credential);
          _currentUser = result.user;
          notifyListeners();
          return AuthResult.success(result.user!);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          // There is already a Google-linked account for this user.
          // Sign into the existing account and merge local data.
          return await _signInAndMerge(credential);
        }
        return AuthResult.error(e.message ?? e.code);
      }
    } catch (e) {
      return AuthResult.error('Google sign-in failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In
  // ---------------------------------------------------------------------------

  Future<AuthResult> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final anonUser = _firebaseAuth.currentUser;

      try {
        if (anonUser != null && anonUser.isAnonymous) {
          final UserCredential linked =
              await anonUser.linkWithCredential(credential);

          // Apple only sends the name the first time; persist it if present.
          final displayName = [
            appleCredential.givenName ?? '',
            appleCredential.familyName ?? '',
          ].where((p) => p.isNotEmpty).join(' ').trim();
          if (displayName.isNotEmpty) {
            await linked.user?.updateDisplayName(displayName);
          }

          _currentUser = linked.user;
          notifyListeners();
          return AuthResult.success(linked.user!);
        } else {
          final UserCredential result =
              await _firebaseAuth.signInWithCredential(credential);
          _currentUser = result.user;
          notifyListeners();
          return AuthResult.success(result.user!);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          return await _signInAndMerge(credential);
        }
        return AuthResult.error(e.message ?? e.code);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.cancelled();
      }
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error('Apple sign-in failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {/* no-op */}

      await _firebaseAuth.signOut();

      // Re-create an anonymous session so the local app always has a uid.
      final cred = await _firebaseAuth.signInAnonymously();
      _currentUser = cred.user;
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService: signOut failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Called when `linkWithCredential` fails with `credential-already-in-use`.
  /// We sign into the *existing* account, then let the sync layer merge
  /// whatever local data belonged to the anonymous user.
  Future<AuthResult> _signInAndMerge(AuthCredential credential) async {
    try {
      final String? anonUid = _firebaseAuth.currentUser?.uid;

      final UserCredential result =
          await _firebaseAuth.signInWithCredential(credential);
      _currentUser = result.user;
      notifyListeners();

      // The sync layer will observe the auth state change and call
      // AccountSyncService.syncAfterLogin which will merge the old anon
      // uid's data into this account.
      if (anonUid != null && anonUid != result.user?.uid) {
        debugPrint(
          'AuthService: merged anonymous uid=$anonUid -> ${result.user?.uid}',
        );
      }

      return AuthResult.success(result.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(e.message ?? e.code);
    } catch (e) {
      return AuthResult.error('Sign-in merge failed: $e');
    }
  }
}
