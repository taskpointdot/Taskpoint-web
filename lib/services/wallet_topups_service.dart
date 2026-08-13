import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// Manual wallet top-up confirmation.
///
/// The mobile app's `WalletService.submitTopUp()` writes three things: the
/// proof screenshot to Storage, a `wallet_topups` doc with status `pending`,
/// and a matching `transactions` ledger row also marked `pending`. It
/// deliberately does NOT credit the balance — that only happens here, once a
/// human has checked the EasyPaisa/JazzCash transfer really landed.
class WalletTopUpsService {
  WalletTopUpsService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _topups => _db.collection('wallet_topups');

  Stream<List<TopUpRequest>> watchByStatus(String status) {
    return _topups.where('status', isEqualTo: status).limit(100).snapshots().map((snap) {
      final list = snap.docs.map(TopUpRequest.fromDoc).toList()
        ..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null || bt == null) return 0;
          return at.compareTo(bt);
        });
      return list;
    });
  }

  /// Credits the user's wallet and settles the ledger row, atomically.
  ///
  /// All three writes go in one transaction so a half-applied approval can't
  /// happen — crediting a balance without marking the request confirmed
  /// would let the same transfer be approved twice.
  Future<void> approve(TopUpRequest request, {required String reviewedBy}) async {
    final topupRef = _topups.doc(request.id);
    final userRef = _db.collection('users').doc(request.userId);
    final ledgerRef = await _ledgerRowFor(request);

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(topupRef);
      // Guards the double-approve race: two admins with the queue open, both
      // clicking Approve on the same row.
      if ((fresh.data()?['status'] as String?) != 'pending') {
        throw StateError('This top-up has already been reviewed.');
      }
      tx.update(topupRef, {
        'status': 'confirmed',
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {'walletBalance': FieldValue.increment(request.amount)});
      if (ledgerRef != null) {
        tx.update(ledgerRef, {
          'status': 'confirmed',
          'label': '${request.method} top-up (confirmed)',
        });
      }
    });
  }

  Future<void> reject(TopUpRequest request, {required String reviewedBy, required String reason}) async {
    final topupRef = _topups.doc(request.id);
    final ledgerRef = await _ledgerRowFor(request);

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(topupRef);
      if ((fresh.data()?['status'] as String?) != 'pending') {
        throw StateError('This top-up has already been reviewed.');
      }
      tx.update(topupRef, {
        'status': 'rejected',
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });
      if (ledgerRef != null) {
        tx.update(ledgerRef, {'status': 'rejected', 'label': '${request.method} top-up (rejected)'});
      }
    });
    // Balance is untouched — it was never credited in the first place.
  }

  /// Finds the `transactions` row that pairs with this top-up.
  ///
  /// Newer submissions carry a `topupId` back-reference (added to
  /// WalletService.submitTopUp for exactly this lookup). Rows written before
  /// that fall back to matching on user + amount + pending status, and if
  /// nothing matches we return null rather than guessing — the balance
  /// credit is the part that actually matters, and a missing ledger row
  /// shouldn't block an approval.
  Future<DocumentReference<Map<String, dynamic>>?> _ledgerRowFor(TopUpRequest request) async {
    final byId = await _db
        .collection('transactions')
        .where('topupId', isEqualTo: request.id)
        .limit(1)
        .get();
    if (byId.docs.isNotEmpty) return byId.docs.first.reference;

    final legacy = await _db
        .collection('transactions')
        .where('userId', isEqualTo: request.userId)
        .where('type', isEqualTo: 'topup')
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in legacy.docs) {
      if (((doc.data()['amount'] as num?)?.toDouble() ?? -1) == request.amount) {
        return doc.reference;
      }
    }
    return null;
  }
}
