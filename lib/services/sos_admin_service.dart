import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// Emergency alerts raised from the mobile app's SOS countdown screen
/// (`sos_logs/{id}`).
///
/// The mobile app deliberately doesn't send SMS or place calls — that's a
/// device-level action Firebase can't do — so this queue is the only place
/// an unattended SOS becomes visible to anyone. Treat it as the highest
/// priority module in the dashboard.
class SosAdminService {
  SosAdminService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _logs => _db.collection('sos_logs');

  Stream<List<SosAlert>> watch({required bool resolved}) {
    return _logs.where('resolved', isEqualTo: resolved).limit(100).snapshots().map((snap) {
      final list = snap.docs.map(SosAlert.fromDoc).toList()
        ..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at); // most recent emergency first
        });
      return list;
    });
  }

  Future<void> resolve(String id, {required String reviewedBy, String note = ''}) {
    return _logs.doc(id).update({
      'resolved': true,
      'resolvedBy': reviewedBy,
      'resolvedAt': FieldValue.serverTimestamp(),
      if (note.isNotEmpty) 'resolutionNote': note,
    });
  }
}
