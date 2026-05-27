import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:agrosetu_app/services/api_service.dart';

class SocialAuthService {
  static const String _webClientId =
      '666169833803-mdpcvgsfvt6r1itejpd0f4pjprncvk4u.apps.googleusercontent.com';

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return {
          'status': 'error',
          'message': 'Google Sign-In is not supported on this platform',
        };
      }

      // v7: authenticate() replaces signIn(). It throws (not returns null) on
      // cancel, so we catch GoogleSignInException explicitly.
      final GoogleSignInAccount account;
      try {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: const ['email', 'profile'],
        );
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return {
            'status': 'error',
            'message': 'User cancelled Google sign-in',
          };
        }
        debugPrint('[SocialAuth] GoogleSignInException: ${e.code} ${e.description}');
        return {
          'status': 'error',
          'message': 'Google sign-in failed: ${e.description ?? e.code.name}',
        };
      }

      // v7: authentication is now SYNCHRONOUS and only exposes idToken.
      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        return {
          'status': 'error',
          'message': 'Failed to obtain ID token. '
              'Check serverClientId and OAuth client setup.',
        };
      }

      debugPrint('[SocialAuth] Google sign-in OK: ${account.email}');

      // Hand off to backend — preserves your existing contract.
      final result = await ApiService.googleLogin(idToken);
      return result;
    } catch (e) {
      debugPrint('[SocialAuth] Google sign-in error: $e');
      return {'status': 'error', 'message': 'Google sign-in failed: $e'};
    }
  }

  static Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[SocialAuth] Sign-out error: $e');
    }
  }
}