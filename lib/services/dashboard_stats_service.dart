import 'package:cloud_firestore/cloud_firestore.dart';

/// Live counts behind the Dashboard metric cards.
///
/// Each getter is a `count()` aggregate query rather than a full document
/// fetch, so the dashboard costs a handful of index reads instead of
/// downloading every user and job just to show six numbers.
///
/// These replace the hard-coded '—' placeholders the dashboard shipped with.
class DashboardStatsService {
  DashboardStatsService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  Future<int> pendingCnicCount() =>
      _count(_db.collection('users').where('cnicStatus', isEqualTo: 'pending'));

  Future<int> pendingTopUpCount() =>
      _count(_db.collection('wallet_topups').where('status', isEqualTo: 'pending'));

  Future<int> openReportsCount() =>
      _count(_db.collection('reports').where('status', isEqualTo: 'open'));

  /// Everyone who has picked a role — i.e. finished onboarding. Users who
  /// signed in but abandoned before role selection aren't "active users".
  Future<int> activeUsersCount() async {
    final seekers = await _count(_db.collection('users').where('role', isEqualTo: 'seeker'));
    final workers = await _count(_db.collection('users').where('role', isEqualTo: 'worker'));
    return seekers + workers;
  }

  Future<int> jobsTodayCount() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _count(
      _db.collection('jobs').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)),
    );
  }

  Future<int> unresolvedSosCount() =>
      _count(_db.collection('sos_logs').where('resolved', isEqualTo: false));

  /// Everything the dashboard needs, fetched concurrently so the six cards
  /// settle together rather than popping in one at a time.
  Future<DashboardStats> loadAll() async {
    final results = await Future.wait([
      pendingCnicCount(),
      pendingTopUpCount(),
      openReportsCount(),
      activeUsersCount(),
      jobsTodayCount(),
      unresolvedSosCount(),
    ]);
    return DashboardStats(
      pendingCnic: results[0],
      pendingTopUps: results[1],
      openReports: results[2],
      activeUsers: results[3],
      jobsToday: results[4],
      unresolvedSos: results[5],
    );
  }
}

class DashboardStats {
  final int pendingCnic;
  final int pendingTopUps;
  final int openReports;
  final int activeUsers;
  final int jobsToday;
  final int unresolvedSos;

  const DashboardStats({
    required this.pendingCnic,
    required this.pendingTopUps,
    required this.openReports,
    required this.activeUsers,
    required this.jobsToday,
    required this.unresolvedSos,
  });
}
