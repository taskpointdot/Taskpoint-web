import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-side models for the collections the seeker/provider app
/// (`taskpoint/`) writes. Field names here must stay in step with the mobile
/// app's services — the two apps share one Firestore project, and these are
/// the same documents seen from the moderator's side.
///
/// These are deliberately read-oriented: the admin app never constructs a
/// user or a job, it only reviews and annotates what the mobile app created.

// Every reader below is *total*: it returns a sensible value for any input
// rather than throwing on an unexpected type.
//
// This matters more than it looks. These models are parsed with
// `snap.docs.map(AdminUser.fromDoc)`, so a single document with one
// off-type field (a phone number saved as a number, a `createdAt` written as
// a string, a `location` stored as a map) used to throw and take the *entire*
// queue down with it — which is precisely why the CNIC "Pending" tab rendered
// nothing while "Verified" (which had no documents to parse) rendered fine.

String _str(Map<String, dynamic> d, String key, [String fallback = '']) {
  final v = d[key];
  if (v == null) return fallback;
  if (v is String) return v.isEmpty ? fallback : v;
  return v.toString();
}

double _num(Map<String, dynamic> d, String key) {
  final v = d[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

bool _bool(Map<String, dynamic> d, String key, [bool fallback = false]) {
  final v = d[key];
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

GeoPoint? _geo(Map<String, dynamic> d, String key) {
  final v = d[key];
  return v is GeoPoint ? v : null;
}

/// Tolerates the several shapes a timestamp can arrive in: a real Firestore
/// [Timestamp], an ISO string, or epoch milliseconds.
DateTime? _time(Map<String, dynamic> d, String key) {
  final v = d[key];
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

/// A nullable URL field: null (rather than an empty string) when absent, so
/// callers can distinguish "no photo uploaded" from "photo failed to load".
String? _url(Map<String, dynamic> d, String key) {
  final v = d[key];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

/// Mirrors `users/{uid}` — both seekers and providers live in one collection,
/// distinguished by `role`.
class AdminUser {
  final String uid;
  final String phone;
  final String name;
  final String email;

  /// 'seeker' | 'worker' | '' when they haven't chosen yet.
  final String role;

  /// 'unsubmitted' | 'pending' | 'verified' | 'rejected'
  final String cnicStatus;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final double walletBalance;
  final bool isOnline;

  /// Set by the admin Users module. The mobile app signs a suspended user
  /// out on sight — see SessionController in `taskpoint/`.
  final bool suspended;
  final GeoPoint? location;
  final DateTime? createdAt;

  const AdminUser({
    required this.uid,
    required this.phone,
    required this.name,
    required this.email,
    required this.role,
    required this.cnicStatus,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.walletBalance = 0,
    this.isOnline = false,
    this.suspended = false,
    this.location,
    this.createdAt,
  });

  bool get isWorker => role == 'worker';
  String get displayName => name.trim().isEmpty ? '(no name)' : name.trim();
  String get roleLabel => switch (role) {
        'worker' => 'Service Provider',
        'seeker' => 'Service Seeker',
        _ => 'Role not set',
      };

  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AdminUser.fromMap(doc.id, doc.data() ?? const {});

  /// Split out from [fromDoc] so the parsing rules can be exercised directly
  /// against plain maps in tests, without needing a Firestore snapshot.
  factory AdminUser.fromMap(String uid, Map<String, dynamic> d) {
    return AdminUser(
      uid: uid,
      phone: _str(d, 'phone'),
      name: _str(d, 'name'),
      email: _str(d, 'email'),
      role: _str(d, 'role'),
      cnicStatus: _str(d, 'cnicStatus', 'unsubmitted'),
      cnicFrontUrl: _url(d, 'cnicFrontUrl'),
      cnicBackUrl: _url(d, 'cnicBackUrl'),
      walletBalance: _num(d, 'walletBalance'),
      isOnline: _bool(d, 'isOnline'),
      suspended: _bool(d, 'suspended'),
      location: _geo(d, 'location'),
      createdAt: _time(d, 'createdAt'),
    );
  }
}

/// Mirrors `wallet_topups/{id}` — a manual EasyPaisa/JazzCash transfer the
/// user claims to have made, with a proof screenshot, awaiting confirmation.
class TopUpRequest {
  final String id;
  final String userId;
  final double amount;
  final String method;
  final String? proofUrl;

  /// 'pending' | 'confirmed' | 'rejected'
  final String status;
  final DateTime? createdAt;

  const TopUpRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    this.proofUrl,
    required this.status,
    this.createdAt,
  });

  factory TopUpRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TopUpRequest(
      id: doc.id,
      userId: _str(d, 'userId'),
      amount: _num(d, 'amount'),
      method: _str(d, 'method', 'Transfer'),
      proofUrl: _url(d, 'proofUrl'),
      status: _str(d, 'status', 'pending'),
      createdAt: _time(d, 'createdAt'),
    );
  }
}

/// Mirrors `reports/{id}`. Two shapes land in this collection: an app-wide
/// "Report a Problem" issue (no `targetUserId`) and a report against a
/// specific worker (`targetUserId` set) — see ReportsService and
/// WorkerProfileActionsService in the mobile app.
class AdminReport {
  final String id;
  final String reporterId;
  final String? targetUserId;
  final String reason;
  final String details;
  final String? evidenceUrl;

  /// 'open' | 'resolved' | 'dismissed'
  final String status;
  final DateTime? createdAt;

  const AdminReport({
    required this.id,
    required this.reporterId,
    this.targetUserId,
    required this.reason,
    required this.details,
    this.evidenceUrl,
    required this.status,
    this.createdAt,
  });

  bool get isAgainstWorker => targetUserId != null && targetUserId!.isNotEmpty;

  factory AdminReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminReport(
      id: doc.id,
      reporterId: _str(d, 'reporterId'),
      targetUserId: _url(d, 'targetUserId'),
      reason: _str(d, 'reason'),
      details: _str(d, 'details'),
      evidenceUrl: _url(d, 'evidenceUrl'),
      status: _str(d, 'status', 'open'),
      createdAt: _time(d, 'createdAt'),
    );
  }
}

/// Mirrors `jobs/{id}`.
class AdminJob {
  final String id;
  final String seekerId;
  final String categoryName;
  final String description;
  final double budget;

  /// 'posted' | 'negotiating' | 'accepted' | 'in_progress' | 'completed' | 'cancelled'
  final String status;
  final String? acceptedWorkerId;
  final String? acceptedWorkerName;
  final double? acceptedPrice;
  final String? address;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const AdminJob({
    required this.id,
    required this.seekerId,
    required this.categoryName,
    required this.description,
    required this.budget,
    required this.status,
    this.acceptedWorkerId,
    this.acceptedWorkerName,
    this.acceptedPrice,
    this.address,
    this.createdAt,
    this.completedAt,
  });

  double get effectivePrice => acceptedPrice ?? budget;

  String get statusLabel => switch (status) {
        'posted' => 'Posted',
        'negotiating' => 'Negotiating',
        'accepted' => 'Accepted',
        'in_progress' => 'In Progress',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  factory AdminJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminJob(
      id: doc.id,
      seekerId: _str(d, 'seekerId'),
      categoryName: _str(d, 'categoryName', 'General'),
      description: _str(d, 'description'),
      budget: _num(d, 'budget'),
      status: _str(d, 'status', 'posted'),
      acceptedWorkerId: _url(d, 'acceptedWorkerId'),
      acceptedWorkerName: _url(d, 'acceptedWorkerName'),
      acceptedPrice: d['acceptedPrice'] == null ? null : _num(d, 'acceptedPrice'),
      address: _url(d, 'address'),
      createdAt: _time(d, 'createdAt'),
      completedAt: _time(d, 'completedAt'),
    );
  }
}

/// Mirrors `categories/{id}` — the service taxonomy on the seeker home.
/// `iconKey` maps to a Material Symbol in the mobile app's ui_models.dart;
/// the admin edits it as a string so both apps stay in sync without the
/// admin needing that icon table.
class AdminCategory {
  final String id;
  final String name;
  final String localName;
  final String iconKey;
  final int order;

  const AdminCategory({
    required this.id,
    required this.name,
    required this.localName,
    required this.iconKey,
    required this.order,
  });

  factory AdminCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminCategory(
      id: doc.id,
      name: _str(d, 'name'),
      localName: _str(d, 'localName'),
      iconKey: _str(d, 'iconKey', 'handyman'),
      order: _num(d, 'order').toInt(),
    );
  }
}

/// Mirrors `sos_logs/{id}` — an emergency alert raised from the mobile app's
/// SOS countdown screen, with the user's location at the time.
class SosAlert {
  final String id;
  final String userId;
  final GeoPoint? location;
  final bool resolved;
  final DateTime? createdAt;

  const SosAlert({
    required this.id,
    required this.userId,
    this.location,
    required this.resolved,
    this.createdAt,
  });

  factory SosAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SosAlert(
      id: doc.id,
      userId: _str(d, 'userId'),
      location: _geo(d, 'location'),
      resolved: _bool(d, 'resolved'),
      createdAt: _time(d, 'createdAt'),
    );
  }
}
