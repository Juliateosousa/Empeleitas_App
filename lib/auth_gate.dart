import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  final Widget loggedIn;
  final Widget loggedOut;

  const AuthGate({
    super.key,
    required this.loggedIn,
    required this.loggedOut,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data != null ? loggedIn : loggedOut;
      },
    );
  }
}
