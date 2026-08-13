import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// Moderation queue over `reports/{id}`.
///
/// Two producers write here, and the module shows both:
///   * `ReportsService.submit()` — an app-wide "Report a Problem" issue.
///   * `WorkerProfileActionsService.reportWorker()` — a complaint against a
///     specific provider, which additionally carries `targetUserId`.
class ReportsAdminService {
  ReportsAdminService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');

  /// [status] is 'open', 'resolved' or 'dismissed'. Sorted newest-first
  /// client-side to avoid requiring a status+createdAt composite index.
  Stream<List<AdminReport>> watchByStatus(String status) {
    return _reports.where('status', isEqualTo: status).limit(100).snapshots().map((snap) {
      final list = snap.docs.map(AdminReport.fromDoc).toList()
        ..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at);
        });
      return list;
    });
  }

  Future<void> resolve(String reportId, {required String reviewedBy, String note = ''}) {
    return _reports.doc(reportId).update({
      'status': 'resolved',
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (note.isNotEmpty) 'resolutionNote': note,
    });
  }

  Future<void> dismiss(String reportId, {required String reviewedBy, String note = ''}) {
    return _reports.doc(reportId).update({
      'status': 'dismissed',
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (note.isNotEmpty) 'resolutionNote': note,
    });
  }

  Future<void> reopen(String reportId) {
    return _reports.doc(reportId).update({'status': 'open'});
  }
}
