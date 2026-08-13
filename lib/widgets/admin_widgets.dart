import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:web/web.dart' as web;

import '../models/admin_models.dart';
import '../services/users_admin_service.dart';
import '../theme/app_theme.dart';
import 'web_image.dart';

/// Shared chrome for every admin module, so the seven sections don't each
/// reinvent a header, an empty state and a status pill.

/// Standard page frame: title, subtitle, optional toolbar, scrolling body.
class AdminSectionScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? toolbar;
  final Widget child;

  const AdminSectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.toolbar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headlineLg),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              if (toolbar != null) ...[
                const SizedBox(height: 16),
                toolbar!,
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

/// Segmented filter used across the queues (Pending / Approved / Rejected…).
///
/// Note for callers: this is a [Wrap], which needs a bounded width. Do **not**
/// place it inside a [Row] — a Row hands its non-flex children an unbounded
/// width, and an unbounded Wrap breaks layout for the whole surrounding
/// column (the symptom is the section title, subtitle and chips all painting
/// on top of one another, plus a flood of hit-test assertions in the console).
/// Use [trailing] to put an extra control beside the chips instead; it sits
/// inside this same Wrap, so it stays bounded and wraps to a new line when
/// space runs out.
class AdminFilterTabs extends StatelessWidget {
  final List<String> labels;
  final int current;
  final ValueChanged<int> onSelect;

  /// Optional control shown after the chips, inside the same Wrap.
  final Widget? trailing;

  const AdminFilterTabs({
    super.key,
    required this.labels,
    required this.current,
    required this.onSelect,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          ChoiceChip(
            label: Text(labels[i]),
            selected: current == i,
            onSelected: (_) => onSelect(i),
            selectedColor: AppColors.primaryContainer,
            labelStyle: AppTextStyles.labelSm.copyWith(
              color: current == i ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
            ),
          ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Coloured pill for a document's status field.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});

  (Color, Color) get _colors => switch (status.toLowerCase()) {
        'verified' || 'confirmed' || 'resolved' || 'completed' => (AppColors.statusGreenBg, AppColors.statusGreenFg),
        'pending' || 'open' || 'posted' || 'negotiating' => (AppColors.statusAmberBg, AppColors.statusAmberFg),
        'rejected' || 'cancelled' || 'dismissed' || 'suspended' => (AppColors.errorContainer, AppColors.onErrorContainer),
        _ => (AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(status.toUpperCase(), style: AppTextStyles.labelSm.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// Centred placeholder for an empty queue — distinct from the old
/// "Coming soon" screen, which meant the module didn't exist. This one
/// means the module works and there's genuinely nothing to action.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const AdminEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class AdminErrorState extends StatelessWidget {
  final Object error;
  const AdminErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final isPermission = message.contains('permission-denied') || message.contains('PERMISSION_DENIED');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.error_rounded, size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Could not load this section', style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                isPermission
                    // By far the most likely cause, and the one that isn't
                    // obvious from the raw Firestore error.
                    ? 'Firestore denied this read. Publish the updated firestore.rules from the '
                        'taskpoint/ project (it adds the admins collection and the isAdmin() '
                        'clauses this dashboard needs), then reload.'
                    : message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled key/value row inside a detail card.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(child: SelectableText(value, style: AppTextStyles.bodyMd)),
        ],
      ),
    );
  }
}

/// White rounded card used for each row in the review queues.
class AdminCard extends StatelessWidget {
  final Widget child;
  const AdminCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}

/// Prompts for a short free-text reason (rejection, suspension, dispute
/// note). Returns null if the admin cancels — callers must treat that as
/// "don't perform the action".
Future<String?> promptForReason(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String hint = 'Reason',
  bool required = true,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(labelText: hint, errorText: error, border: const OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) {
                  setState(() => error = 'Please give a reason');
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      );
    },
  );
}

/// Full-size preview for a CNIC / proof-of-payment image.
///
/// The URLs stored on the documents are Firebase Storage *download* URLs,
/// which carry their own access token and are readable without the viewer
/// needing Storage read permission — which is what makes this work without
/// granting the admin blanket access to everyone's CNIC folder.
void showImagePreview(BuildContext context, String url, String title) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppTextStyles.headlineMd)),
                  IconButton(
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // StorageImage fetches the bytes and paints them natively, so the
            // cross-origin Firebase Storage photo renders under CanvasKit. The
            // dialog is large enough (up to 900x720) to read a CNIC at
            // contain-fit; for a closer look the operator can open the raw URL
            // via the button below.
            Flexible(child: StorageImage(url: url, fit: BoxFit.contain)),
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: () => web.window.open(url, '_blank'),
                  icon: const Icon(Symbols.open_in_new_rounded, size: 18),
                  label: const Text('Open full size'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Resolves a bare `userId` into a readable name + phone.
///
/// The top-up, report and SOS documents only store the UID, so without this
/// every row in those queues would read as a 28-character opaque string.
/// Lookups are memoised in [_userCache] so scrolling a queue of 50 rows for
/// the same handful of users doesn't re-fetch each one.
class UserRefLine extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  const UserRefLine({super.key, required this.uid, this.style});

  static final Map<String, Future<AdminUser?>> _userCache = {};

  static Future<AdminUser?> _lookup(String uid) =>
      _userCache.putIfAbsent(uid, () => UsersAdminService().fetch(uid));

  /// Call after an action that changes a user, so the next render re-reads
  /// them instead of showing a stale cached name.
  static void invalidate(String uid) => _userCache.remove(uid);

  @override
  Widget build(BuildContext context) {
    final effective = style ?? AppTextStyles.bodyMd;
    return FutureBuilder<AdminUser?>(
      future: _lookup(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Text(uid, style: effective.copyWith(color: AppColors.onSurfaceVariant));
        }
        final user = snap.data!;
        return Text(
          '${user.displayName} · ${user.phone.isEmpty ? user.uid : user.phone}',
          style: effective,
        );
      },
    );
  }
}

/// Consistent short timestamp for list rows.
String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}
