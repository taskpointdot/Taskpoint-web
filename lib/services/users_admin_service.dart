import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// Directory over `users/{uid}` — both service seekers and service
/// providers, since the mobile app keeps them in one collection separated by
/// a `role` field.
class UsersAdminService {
  UsersAdminService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// [role] is 'seeker', 'worker', or null for everyone.
  ///
  /// Search is applied client-side over the streamed page rather than as a
  /// Firestore query: Firestore has no substring/`contains` operator, so
  /// matching a partial name or phone number server-side would mean adding a
  /// search index service. At this app's scale filtering the loaded page is
  /// the honest trade.
  Stream<List<AdminUser>> watchUsers({String? role, String query = '', int limit = 200}) {
    Query<Map<String, dynamic>> q = _users;
    if (role != null) q = q.where('role', isEqualTo: role);
    return q.limit(limit).snapshots().map((snap) {
      var users = snap.docs.map(AdminUser.fromDoc).toList();
      final needle = query.trim().toLowerCase();
      if (needle.isNotEmpty) {
        users = users
            .where((u) =>
                u.name.toLowerCase().contains(needle) ||
                u.phone.toLowerCase().contains(needle) ||
                u.email.toLowerCase().contains(needle) ||
                u.uid.toLowerCase().contains(needle))
            .toList();
      }
      users.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null || bt == null) return a.displayName.compareTo(b.displayName);
        return bt.compareTo(at);
      });
      return users;
    });
  }

  Future<AdminUser?> fetch(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AdminUser.fromDoc(doc) : null;
  }

  /// Suspending also forces the provider offline, so a suspended worker
  /// stops appearing on seekers' "Nearby Workers" map immediately rather
  /// than lingering until they next open the app.
  ///
  /// The mobile app's SessionController watches this field and signs a
  /// suspended user straight back out.
  Future<void> setSuspended(String uid, bool suspended, {required String actedBy, String reason = ''}) {
    return _users.doc(uid).update({
      'suspended': suspended,
      if (suspended) 'isOnline': false,
      'suspendedBy': suspended ? actedBy : FieldValue.delete(),
      'suspendedAt': suspended ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'suspensionReason': suspended && reason.isNotEmpty ? reason : FieldValue.delete(),
    });
  }
}
