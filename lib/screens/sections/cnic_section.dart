import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:web/web.dart' as web;

import '../../models/admin_models.dart';
import '../../services/cnic_review_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/web_image.dart';

/// CNIC identity verification queue.
///
/// This is the gate the mobile app puts every new user behind: until
/// `cnicStatus` becomes 'verified', SessionController.startRoute keeps
/// sending them back to the CNIC screen. Before this module existed the only
/// way past it was editing the field by hand in the Firebase console.
class CnicSection extends StatefulWidget {
  final String reviewerName;
  const CnicSection({super.key, required this.reviewerName});

  @override
  State<CnicSection> createState() => _CnicSectionState();
}

class _CnicSectionState extends State<CnicSection> {
  final _service = CnicReviewService();
  int _tab = 0;
  final _busy = <String>{};

  // The Firestore stream is created ONCE per selected tab and held in state.
  // The previous code built a fresh `watchPending()` stream inside the
  // StreamBuilder on every rebuild — each rebuild handed StreamBuilder a new
  // stream, which reset it back to the loading spinner and re-subscribed a new
  // Firestore listener, so the list could sit spinning and never settle.
  late Stream<List<AdminUser>> _stream = _streamFor(0);

  Stream<List<AdminUser>> _streamFor(int tab) => switch (tab) {
        0 => _service.watchPending(),
        1 => _service.watchReviewed(verified: true),
        _ => _service.watchReviewed(verified: false),
      };

  void _selectTab(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _stream = _streamFor(tab);
    });
  }

  /// Rebuilds the current tab's stream, which re-runs its one-shot server
  /// read. Needed because the live listener can't be relied on in every
  /// network environment — without this, a queue would keep showing a user
  /// who has just been approved.
  void _refresh() => setState(() => _stream = _streamFor(_tab));

  Future<void> _run(String uid, Future<void> Function() action, String successMessage) async {
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      // Re-read from the server so the reviewed user leaves this queue even
      // when the real-time listener isn't delivering updates.
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  Future<void> _approve(AdminUser user) =>
      _run(user.uid, () => _service.approve(user.uid, reviewedBy: widget.reviewerName), '${user.displayName} verified');

  Future<void> _reject(AdminUser user) async {
    final reason = await promptForReason(
      context,
      title: 'Reject ${user.displayName}?',
      actionLabel: 'Reject',
      hint: 'What was wrong with the photos?',
    );
    if (reason == null) return;
    await _run(
      user.uid,
      () => _service.reject(user.uid, reviewedBy: widget.reviewerName, reason: reason),
      '${user.displayName} rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'CNIC Verifications',
      subtitle: 'Approve or reject identity documents before a user can take or post work.',
      toolbar: AdminFilterTabs(
        labels: const ['Pending', 'Verified', 'Rejected'],
        current: _tab,
        onSelect: _selectTab,
        trailing: OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Symbols.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ),
      child: StreamBuilder<List<AdminUser>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) return const _QueueLoading();
          final users = snap.data!;
          if (users.isEmpty) {
            return AdminEmptyState(
              icon: Symbols.verified_user_rounded,
              message: _tab == 0 ? 'Nothing waiting for review.' : 'No users in this state.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) => _CnicCard(
              key: ValueKey(users[i].uid),
              user: users[i],
              busy: _busy.contains(users[i].uid),
              showActions: _tab == 0,
              onApprove: () => _approve(users[i]),
              onReject: () => _reject(users[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Loading state for the queue that stops being a mystery after a while: if
/// the Firestore stream hasn't produced its first snapshot within a few
/// seconds, it means the real-time listener isn't reaching Firestore (the
/// usual "the screen just spins and never loads" report), so it says so and
/// offers a retry instead of an eternal spinner.
class _QueueLoading extends StatefulWidget {
  const _QueueLoading();

  @override
  State<_QueueLoading> createState() => _QueueLoadingState();
}

class _QueueLoadingState extends State<_QueueLoading> {
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_slow) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.cloud_off_rounded, size: 40, color: AppColors.outline),
              const SizedBox(height: 12),
              Text('Still loading the queue…', style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                "The real-time connection to Firestore hasn't responded yet. This is "
                'usually a network/proxy/VPN or browser extension blocking the '
                "streaming channel. Reload the page, or open the dashboard in a normal "
                'Chrome window.',
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

class _CnicCard extends StatelessWidget {
  final AdminUser user;
  final bool busy;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _CnicCard({
    super.key,
    required this.user,
    required this.busy,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final headline = user.displayName;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.secondaryContainer,
                child: Text(
                  headline[0].toUpperCase(),
                  style: AppTextStyles.labelLg.copyWith(color: AppColors.onSecondaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: AppTextStyles.headlineMd, overflow: TextOverflow.ellipsis),
                    Text('${user.roleLabel} · ${user.phone}',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              StatusPill(status: user.cnicStatus),
            ],
          ),
          const Divider(height: 28),
          // A Wrap, not a Row. The two thumbnails plus the details column need
          // ~460px side by side; whenever the content area was narrower than
          // that (an ordinary window, or any window with DevTools open) the
          // Row overflowed, the Expanded child resolved to a negative width,
          // and the card failed to lay out — which is what made the Pending
          // queue render as an empty page while Verified/Rejected, having no
          // cards to build, looked fine. A Wrap reflows instead of breaking.
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              _CnicThumb(label: 'CNIC Front', url: user.cnicFrontUrl, ownerName: user.displayName),
              _CnicThumb(label: 'CNIC Back', url: user.cnicBackUrl, ownerName: user.displayName),
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'User ID', value: user.uid),
                    DetailRow(label: 'Email', value: user.email.isEmpty ? '—' : user.email),
                    DetailRow(label: 'Registered', value: formatDateTime(user.createdAt)),
                  ],
                ),
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            // Wrap rather than Row + Spacer: on a narrow card the buttons drop
            // to their own line instead of overflowing and collapsing the card.
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Symbols.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreenFg,
                      foregroundColor: Colors.white,
                    ),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Symbols.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CnicThumb extends StatelessWidget {
  final String label;
  final String? url;
  final String ownerName;
  const _CnicThumb({required this.label, required this.url, required this.ownerName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        InkWell(
          onTap: url == null ? null : () => showImagePreview(context, url!, '$ownerName — $label'),
          child: Container(
            width: 190,
            height: 120,
            // No clipBehavior here on purpose. Storage's media responses carry
            // no CORS header, so the photo can only be shown through an <img>
            // platform view — and clipping a platform view on Flutter web makes
            // it composite as a solid black rectangle, which is exactly what
            // these thumbnails were showing. Square corners are a small price
            // for a visible document.
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            // StorageImage fetches the bytes and draws them with Image.memory
            // — a native canvas image that appears immediately, unlike the
            // <img> platform-view overlay that lagged in this scrolling list.
            child: url == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.no_photography_rounded, color: AppColors.outlineVariant),
                        const SizedBox(height: 4),
                        Text('No photo on file',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  )
                // Firebase Storage does not send Access-Control-Allow-Origin on
                // its media responses, so the byte-fetch is refused and this
                // always lands on the <img> fallback — which is fine: a browser
                // may *display* a cross-origin image without any CORS grant.
                : StorageImage(url: url!),
          ),
        ),
        // Always-available escape hatch. Inline rendering of a cross-origin
        // Storage image depends on platform-view compositing behaving; opening
        // the URL in a normal tab never does, so the reviewer can always
        // actually look at the document before deciding.
        if (url != null)
          TextButton.icon(
            onPressed: () => web.window.open(url!, '_blank'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Symbols.open_in_new_rounded, size: 14),
            label: const Text('Open in new tab'),
          ),
      ],
    );
  }
}
