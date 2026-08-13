import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskpoint_admin/models/admin_models.dart';

/// Guards the defect that made the CNIC review queue render nothing.
///
/// The queue is built with `snap.docs.map(AdminUser.fromDoc)`. Parsing used
/// raw casts (`d['phone'] as String?`, `d['createdAt'] as Timestamp?`, …), so
/// ONE document with an off-type field threw and destroyed the whole list —
/// which is why "Pending" (2 documents, one of them malformed) showed nothing
/// while "Verified" (0 documents, nothing to parse) rendered correctly.
void main() {
  group('AdminUser parsing is total', () {
    test('reads a well-formed document', () {
      final u = AdminUser.fromMap('uid1', {
        'phone': '+92 300 1112223',
        'name': 'Ahmed',
        'role': 'worker',
        'cnicStatus': 'pending',
        'cnicFrontUrl': 'https://example.com/front.jpg',
        'walletBalance': 250,
        'isOnline': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(u.displayName, 'Ahmed');
      expect(u.phone, '+92 300 1112223');
      expect(u.cnicStatus, 'pending');
      expect(u.cnicFrontUrl, 'https://example.com/front.jpg');
      expect(u.walletBalance, 250);
      expect(u.isOnline, isTrue);
      expect(u.createdAt, DateTime(2026, 1, 1));
    });

    test('survives off-type fields instead of throwing', () {
      // Every field here is the "wrong" type — the shapes that really occur
      // when data is written by different code paths or edited by hand in the
      // Firebase console.
      late AdminUser u;
      expect(
        () => u = AdminUser.fromMap('uid2', {
          'phone': 923001112223, // number, not string
          'name': 42, // number, not string
          'walletBalance': '150.5', // string, not number
          'isOnline': 'true', // string, not bool
          'suspended': 1, // number, not bool
          'location': {'lat': 31.5, 'lng': 74.3}, // map, not GeoPoint
          'createdAt': '2026-01-02T10:30:00Z', // ISO string, not Timestamp
          'cnicStatus': 'pending',
        }),
        returnsNormally,
      );

      expect(u.phone, '923001112223');
      expect(u.name, '42');
      expect(u.walletBalance, 150.5);
      expect(u.isOnline, isTrue);
      expect(u.suspended, isTrue);
      expect(u.location, isNull); // unusable shape degrades to null, not a crash
      expect(u.createdAt, isNotNull);
    });

    test('handles a completely empty document', () {
      late AdminUser u;
      expect(() => u = AdminUser.fromMap('uid3', const {}), returnsNormally);

      expect(u.uid, 'uid3');
      expect(u.displayName, '(no name)');
      expect(u.cnicStatus, 'unsubmitted');
      expect(u.cnicFrontUrl, isNull);
      expect(u.walletBalance, 0);
      expect(u.isOnline, isFalse);
    });

    test('epoch-millisecond timestamps are understood', () {
      final u = AdminUser.fromMap('uid4', {'createdAt': 1767225600000});
      expect(u.createdAt, isNotNull);
    });

    test('blank photo URLs read as "no photo", not an empty string', () {
      final u = AdminUser.fromMap('uid5', {'cnicFrontUrl': '   ', 'cnicBackUrl': ''});
      expect(u.cnicFrontUrl, isNull);
      expect(u.cnicBackUrl, isNull);
    });

    test('one bad document no longer takes the whole queue down', () {
      // Mirrors what CnicReviewService._parse does per document.
      final raw = <Map<String, dynamic>>[
        {'name': 'Good One', 'cnicStatus': 'pending'},
        {'name': 'Bad One', 'cnicStatus': 'pending', 'createdAt': <String, Object>{}},
        {'name': 'Good Two', 'cnicStatus': 'pending'},
      ];

      final parsed = <AdminUser>[];
      for (var i = 0; i < raw.length; i++) {
        try {
          parsed.add(AdminUser.fromMap('uid$i', raw[i]));
        } catch (_) {
          continue;
        }
      }

      // All three survive now; before the fix the malformed middle row threw
      // and the reviewer saw an empty screen.
      expect(parsed.length, 3);
      expect(parsed.map((u) => u.displayName), containsAll(['Good One', 'Good Two']));
    });
  });
}
