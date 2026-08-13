import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// CRUD over `categories/{id}` — the service taxonomy the seeker home
/// dashboard and "All Services" screen are built from.
///
/// The mobile app seeds this collection once on first run and then treats it
/// as read-only; this module is the intended way to change it afterwards.
class CategoriesAdminService {
  CategoriesAdminService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _categories => _db.collection('categories');

  /// The `_seeded` marker doc lives in this collection too (it's how the
  /// mobile app's one-time seed guards itself server-side), so it's filtered
  /// out here rather than shown as an empty category row.
  Stream<List<AdminCategory>> watchAll() {
    return _categories.orderBy('order').snapshots().map(
          (snap) => snap.docs.where((d) => d.id != '_seeded').map(AdminCategory.fromDoc).toList(),
        );
  }

  Future<void> create({
    required String name,
    required String localName,
    required String iconKey,
    required int order,
  }) {
    return _categories.add({
      'name': name,
      'localName': localName,
      'iconKey': iconKey,
      'order': order,
    });
  }

  Future<void> update(
    String id, {
    required String name,
    required String localName,
    required String iconKey,
    required int order,
  }) {
    return _categories.doc(id).update({
      'name': name,
      'localName': localName,
      'iconKey': iconKey,
      'order': order,
    });
  }

  Future<void> delete(String id) => _categories.doc(id).delete();

  /// Icon keys the mobile app knows how to render — these are exactly the
  /// cases in `categoryIconFor()` (taskpoint/lib/models/job.dart). Offering a
  /// fixed list instead of a free-text field stops an admin from saving a key
  /// that would silently fall back to the generic handyman icon on every
  /// seeker's phone.
  ///
  /// Note the spaces: the mobile app matches on the lowercased key verbatim,
  /// so 'ac repair' works and 'ac_repair' does not.
  static const supportedIconKeys = <String>[
    'plumber',
    'electrician',
    'carpenter',
    'painter',
    'mason',
    'cleaner',
    'ac repair',
    'appliance repair',
    'gardener',
    'mover',
    'pest control',
    'car wash',
  ];
}
