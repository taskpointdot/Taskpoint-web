import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// Oversight over `jobs/{id}` — every job in the marketplace, with the
/// dispute-facing ability to cancel one that's gone wrong.
class JobsAdminService {
  JobsAdminService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  /// [status] null means all statuses. The status+createdAt composite index
  /// this needs already exists in the mobile app's firestore.indexes.json.
  Stream<List<AdminJob>> watchJobs({String? status, int limit = 100}) {
    Query<Map<String, dynamic>> q = _jobs;
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots().map(
          (snap) => snap.docs.map(AdminJob.fromDoc).toList(),
        );
  }

  /// Force-cancels a job from the dispute view. Deliberately not a delete:
  /// the record stays for the audit trail, and both sides' job lists show it
  /// as cancelled rather than silently losing it.
  Future<void> cancel(String jobId, {required String actedBy, String reason = ''}) {
    return _jobs.doc(jobId).update({
      'status': 'cancelled',
      'cancelledBy': actedBy,
      'cancelledAt': FieldValue.serverTimestamp(),
      if (reason.isNotEmpty) 'cancellationReason': reason,
    });
  }
}
