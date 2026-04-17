import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web flow
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential result = await _auth.signInWithPopup(googleProvider);
        return result.user;
      } else {
        // Mobile flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential result = await _auth.signInWithCredential(credential);
        return result.user;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  // Sign in anonymously (Legacy/Guest)
  Future<User?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      debugPrint('Auth Error: $e');
      return null;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current UID
  String? get currentUid => _auth.currentUser?.uid;

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Logout Error: $e');
    }
  }
}

