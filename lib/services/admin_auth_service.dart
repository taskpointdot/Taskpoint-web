import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAuthException implements Exception {
  final String message;
  AdminAuthException(this.message);
  @override
  String toString() => message;
}

class AdminProfile {
  final String uid;
  final String email;
  final String name;
  final String role; // e.g. 'super_admin' | 'support' | 'finance'
  const AdminProfile({required this.uid, required this.email, required this.name, required this.role});
}

/// Wraps Firebase Auth + a Firestore `admins` allow-list collection.
///
/// Signing in with Firebase Auth alone doesn't prove someone is an admin —
/// any seeker/provider could sign in with their own TaskPoint account here.
/// This service additionally checks that the signed-in UID has a matching
/// document in `admins`, and immediately signs them back out if not.
///
/// Firestore schema:
///   admins/{uid} -> { name: string, role: string, addedAt: timestamp }
///
/// To add your first admin: create the user in Firebase Auth (console or
/// sign-up flow), copy their UID, then manually create a document at
/// admins/{that uid} in Firestore with a name and role field.
class AdminAuthService {
  AdminAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<AdminProfile> signIn({required String email, required String password}) async {
    final User user;
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final signedInUser = credential.user;
      if (signedInUser == null) {
        throw AdminAuthException('Sign-in failed. Please try again.');
      }
      user = signedInUser;
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_friendlyAuthMessage(e));
    }

    final profile = await _loadProfile(user);
    if (profile == null) {
      await _auth.signOut();
      throw AdminAuthException('This account does not have admin access.');
    }
    return profile;
  }

  /// Looks up the admin profile for an already-signed-in user — used on
  /// app restart, once [authStateChanges] fires with a non-null user.
  /// Returns null (and signs the user out) if they aren't an admin.
  Future<AdminProfile?> loadProfileForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final profile = await _loadProfile(user);
    if (profile == null) {
      await _auth.signOut();
      return null;
    }
    return profile;
  }

  Future<AdminProfile?> _loadProfile(User user) async {
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore.collection('admins').doc(user.uid).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // The single most common cause: Firestore is in production mode
        // and no security rules have been published yet, so every read
        // is denied by default — including this admin-status check.
        throw AdminAuthException(
          "Couldn't verify admin access (permission-denied). "
          'This usually means Firestore security rules haven\'t been '
          'published yet in the Firebase console — see firestore.rules.',
        );
      }
      throw AdminAuthException('Could not verify admin access: ${e.message ?? e.code}');
    }
    if (!doc.exists) return null;
    final data = doc.data()!;
    return AdminProfile(
      uid: user.uid,
      email: user.email ?? '',
      name: (data['name'] as String?) ?? 'Admin',
      role: (data['role'] as String?) ?? 'admin',
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_friendlyAuthMessage(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
