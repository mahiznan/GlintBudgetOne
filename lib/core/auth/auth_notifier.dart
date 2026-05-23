import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_state.dart';

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthLoading()) {
    if (kIsWeb) {
      // Complete any pending redirect sign-in (from signInWithRedirect)
      FirebaseAuth.instance.getRedirectResult().ignore();
    }
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        state = const AuthUnauthenticated();
      } else {
        state = AuthAuthenticated(
          user: AuthUser(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoUrl: user.photoURL,
          ),
        );
      }
    });
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      try {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-blocked' || e.code == 'popup-closed-by-user') {
          // Popup blocked — fall back to redirect flow (page navigates away)
          await FirebaseAuth.instance.signInWithRedirect(provider);
        } else {
          rethrow;
        }
      }
    } else {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
