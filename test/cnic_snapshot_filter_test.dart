import 'package:flutter_test/flutter_test.dart';
import 'package:taskpoint_admin/services/cnic_review_service.dart';

/// Guards the defect where the CNIC queue showed the real pending users for
/// about a second and then went blank.
///
/// Cause: the queue is seeded by a one-shot server read, then kept live by a
/// listener. Firestore answers a new listener from its local cache first; with
/// persistence disabled — and especially when the real-time channel is blocked
/// by a VPN/proxy/antivirus — that first answer is EMPTY. It was being treated
/// as "the queue is empty now" and wiped out the rows already read from the
/// server.
void main() {
  group('shouldIgnoreSnapshot', () {
    test('drops the empty cache-only echo that wipes real server rows', () {
      expect(
        CnicReviewService.shouldIgnoreSnapshot(
          isFromCache: true,
          isEmpty: true,
          haveServerRows: true,
        ),
        isTrue,
      );
    });

    test('honours a genuinely empty server snapshot — queues can empty out', () {
      expect(
        CnicReviewService.shouldIgnoreSnapshot(
          isFromCache: false,
          isEmpty: true,
          haveServerRows: true,
        ),
        isFalse,
      );
    });

    test('honours a cached snapshot that actually carries rows', () {
      expect(
        CnicReviewService.shouldIgnoreSnapshot(
          isFromCache: true,
          isEmpty: false,
          haveServerRows: true,
        ),
        isFalse,
      );
    });

    test('an empty cache echo is fine before any server rows exist', () {
      // Nothing to protect yet, so the empty state is the honest thing to show.
      expect(
        CnicReviewService.shouldIgnoreSnapshot(
          isFromCache: true,
          isEmpty: true,
          haveServerRows: false,
        ),
        isFalse,
      );
    });

    test('normal server updates always pass through', () {
      expect(
        CnicReviewService.shouldIgnoreSnapshot(
          isFromCache: false,
          isEmpty: false,
          haveServerRows: true,
        ),
        isFalse,
      );
    });
  });
}
