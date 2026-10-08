import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // ADMINS
  // ============================================================

  static const Set<String> adminEmails = {
    const String.fromEnvironment('ADMIN_EMAIL_1'),
    const String.fromEnvironment('ADMIN_EMAIL_2'),
  };

  // ============================================================
  // ADMIN CHECK
  // ============================================================

  bool get isAdmin {
    final email = _auth.currentUser?.email?.trim().toLowerCase();

    if (email == null) {
      return false;
    }

    return adminEmails.contains(email);
  }

  // ============================================================
  // EMPLOYEE CHECK
  // ============================================================

  bool get isEmployee {
    final email = _auth.currentUser?.email?.trim().toLowerCase();

    if (email == null) {
      return false;
    }

    return email.endsWith(const String.fromEnvironment('ALLOWED_EMAIL_DOMAIN', defaultValue: '@example.invalid')) && !isAdmin;
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<UserCredential> signInWithGoogleRestrictedDomain() async {
    if (kIsWeb) {
      // Web
      final provider = GoogleAuthProvider();

      final userCred = await _auth.signInWithPopup(provider);

      final email =
          userCred.user?.email?.trim().toLowerCase() ?? "";

      if (!email.endsWith(const String.fromEnvironment('ALLOWED_EMAIL_DOMAIN', defaultValue: '@example.invalid'))) {
        await _auth.signOut();

        throw Exception(
          "Only accounts from the configured organization domain are allowed.",
        );
      }

      return userCred;
    }

    // Mobile
    final googleUser = await GoogleSignIn().signIn();

    if (googleUser == null) {
      throw Exception("Login cancelled");
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred =
        await _auth.signInWithCredential(credential);

    final email =
        userCred.user?.email?.trim().toLowerCase() ?? "";

    if (!email.endsWith(const String.fromEnvironment('ALLOWED_EMAIL_DOMAIN', defaultValue: '@example.invalid'))) {
      await _auth.signOut();
      await GoogleSignIn().signOut();

      throw Exception(
        "Only accounts from the configured organization domain are allowed.",
      );
    }

    return userCred;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser => _auth.currentUser;

  String? get currentUserEmail {
    return _auth.currentUser?.email?.trim().toLowerCase();
  }
}
