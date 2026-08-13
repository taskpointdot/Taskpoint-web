import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// CNIC identity verification queue.
///
/// The mobile app's `CnicService.submit()` uploads the two photos to Storage
/// and sets `users/{uid}.cnicStatus = 'pending'` along with `cnicFrontUrl` /
/// `cnicBackUrl`. There is no separate `cnic_submissions` collection (the
/// admin README predates the mobile implementation and guessed one) — the
/// queue is simply the users sitting in the `pending` state.
///
/// Approving flips that user to `verified`, which is what the mobile app's
/// SessionController.startRoute checks before letting someone past the
/// CNIC gate into the app proper.
class CnicReviewService {
  CnicReviewService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Everyone awaiting review. No `orderBy` here on purpose: adding one
  /// would need a composite index, and the pending queue is small enough
  /// that sorting client-side is cheaper than asking the operator to deploy
  /// an index before the module works at all.
  Stream<List<AdminUser>> watchPending() => _watchByStatus('pending');

  /// Anyone already reviewed, so an admin can audit or reverse a decision.
  Stream<List<AdminUser>> watchReviewed({required bool verified}) =>
      _watchByStatus(verified ? 'verified' : 'rejected');

  /// Emits the queue for [status], then keeps it live.
  ///
  /// The one-shot `get()` first is deliberate. Firestore's real-time channel
  /// is a long-lived streaming connection that antivirus TLS inspection,
  /// VPNs/proxies and some extensions silently block; when that happens
  /// `snapshots()` never emits its first snapshot and the queue sits empty
  /// forever with no error to show. A plain `get()` is an ordinary HTTPS
  /// request that succeeds in those environments, so the reviewer sees their
  /// queue immediately either way, and live updates layer on afterwards.
  Stream<List<AdminUser>> _watchByStatus(String status) async* {
    final query = _users.where('cnicStatus', isEqualTo: status).limit(100);

    List<AdminUser>? lastFromServer;

    try {
      lastFromServer = _parse(await query.get());
      yield lastFromServer;
    } catch (_) {
      // Ignored on purpose: if this read genuinely failed (permissions, no
      // network) the live subscription below raises the same error, and that
      // one reaches the UI as a proper error state.
    }

    await for (final snap in query.snapshots()) {
      // Firestore answers a new listener from its local cache first and only
      // then from the server. When the real-time channel is blocked (VPN,
      // proxy, antivirus TLS inspection) that cached answer is the *only* one
      // that ever arrives — and with persistence disabled it is empty. Letting
      // it through replaced the rows we had just fetched from the server with
      // "nothing to review", which is why the queue flashed the real users for
      // a second and then went blank.
      //
      // So: never let an empty cache-only snapshot discard results we know
      // came from the server. Anything else — including a genuinely empty
      // server response, and every later update — is passed straight through.
      if (shouldIgnoreSnapshot(
        isFromCache: snap.metadata.isFromCache,
        isEmpty: snap.docs.isEmpty,
        haveServerRows: lastFromServer?.isNotEmpty ?? false,
      )) {
        continue;
      }

      final parsed = _parse(snap);
      if (!snap.metadata.isFromCache) lastFromServer = parsed;
      yield parsed;
    }
  }

  /// Whether a live snapshot should be discarded rather than shown.
  ///
  /// True only for the one case that corrupts the view: an **empty**,
  /// **cache-only** snapshot arriving when we already hold rows read from the
  /// server. That combination never means "the queue is now empty" — it means
  /// the listener answered from an empty local cache because it cannot reach
  /// the server. Showing it wipes real data off the screen.
  ///
  /// Deliberately narrow: a genuinely empty *server* snapshot is honoured (a
  /// queue really can become empty), and cached snapshots that carry rows are
  /// honoured too.
  static bool shouldIgnoreSnapshot({
    required bool isFromCache,
    required bool isEmpty,
    required bool haveServerRows,
  }) =>
      isFromCache && isEmpty && haveServerRows;

  /// Parses a snapshot one document at a time.
  ///
  /// Previously this was `snap.docs.map(AdminUser.fromDoc)`, so a single
  /// malformed document threw and destroyed the whole result — one bad row
  /// made the entire review queue disappear. Now a document that can't be
  /// read is skipped and the rest still reach the reviewer.
  List<AdminUser> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final users = <AdminUser>[];
    for (final doc in snap.docs) {
      try {
        users.add(AdminUser.fromDoc(doc));
      } catch (_) {
        continue;
      }
    }
    // Oldest submission first — fairest queue. Undated rows sort last, and
    // the uid tiebreak keeps the order stable between rebuilds (a comparator
    // that returns 0 for unequal items gives an unstable, arbitrary order).
    users.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at != null && bt != null) {
        final byDate = at.compareTo(bt);
        if (byDate != 0) return byDate;
      } else if (at == null && bt != null) {
        return 1;
      } else if (at != null && bt == null) {
        return -1;
      }
      return a.uid.compareTo(b.uid);
    });
    return users;
  }

  Future<void> approve(String uid, {required String reviewedBy}) {
    return _users.doc(uid).update({
      'cnicStatus': 'verified',
      'cnicReviewedBy': reviewedBy,
      'cnicReviewedAt': FieldValue.serverTimestamp(),
      'cnicRejectionReason': FieldValue.delete(),
    });
  }

  /// Rejecting keeps the uploaded photos in place so the user can see what
  /// was rejected, and records why — the mobile CNIC screen shows this back
  /// to them so they know what to re-shoot.
  Future<void> reject(String uid, {required String reviewedBy, required String reason}) {
    return _users.doc(uid).update({
      'cnicStatus': 'rejected',
      'cnicReviewedBy': reviewedBy,
      'cnicReviewedAt': FieldValue.serverTimestamp(),
      'cnicRejectionReason': reason,
    });
  }
}
