import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/admin_models.dart';
import '../../services/wallet_topups_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/web_image.dart';

/// Manual wallet top-up confirmation.
///
/// Approving is the only thing in either app that credits a wallet balance
/// from a bank transfer, so it's deliberately explicit: the admin sees the
/// claimed amount, the method, and the proof screenshot side by side before
/// committing.
class TopUpsSection extends StatefulWidget {
  final String reviewerName;
  const TopUpsSection({super.key, required this.reviewerName});

  @override
  State<TopUpsSection> createState() => _TopUpsSectionState();
}

class _TopUpsSectionState extends State<TopUpsSection> {
  final _service = WalletTopUpsService();
  int _tab = 0;
  final _busy = <String>{};

  static const _statuses = ['pending', 'confirmed', 'rejected'];

  Future<void> _run(String id, Future<void> Function() action, String message) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _approve(TopUpRequest r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm this transfer?'),
        content: Text(
          'This credits Rs. ${r.amount.toStringAsFixed(0)} to the user\'s wallet immediately. '
          'Only do this once you have checked the money actually arrived in the '
          '${r.method} account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Credit wallet')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      r.id,
      () => _service.approve(r, reviewedBy: widget.reviewerName),
      'Rs. ${r.amount.toStringAsFixed(0)} credited',
    );
    UserRefLine.invalidate(r.userId);
  }

  Future<void> _reject(TopUpRequest r) async {
    final reason = await promptForReason(
      context,
      title: 'Reject this top-up?',
      actionLabel: 'Reject',
      hint: 'Why is this being rejected?',
    );
    if (reason == null) return;
    await _run(
      r.id,
      () => _service.reject(r, reviewedBy: widget.reviewerName, reason: reason),
      'Top-up rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'Wallet Top-Ups',
      subtitle: 'Confirm manual EasyPaisa / JazzCash transfers before crediting a wallet.',
      toolbar: AdminFilterTabs(
        labels: const ['Pending', 'Confirmed', 'Rejected'],
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
      child: StreamBuilder<List<TopUpRequest>>(
        stream: _service.watchByStatus(_statuses[_tab]),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snap.data!;
          if (requests.isEmpty) {
            return AdminEmptyState(
              icon: Symbols.account_balance_wallet_rounded,
              message: _tab == 0 ? 'No top-ups waiting for confirmation.' : 'Nothing here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final r = requests[i];
              return AdminCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: r.proofUrl == null
                          ? null
                          : () => showImagePreview(context, r.proofUrl!, 'Transfer proof — Rs. ${r.amount.toStringAsFixed(0)}'),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: 150,
                        height: 150,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        // StorageImage draws the proof natively (see its doc).
                        child: r.proofUrl == null
                            ? const Center(child: Icon(Symbols.receipt_long_rounded, color: AppColors.outlineVariant))
                            : StorageImage(url: r.proofUrl!),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Rs. ${r.amount.toStringAsFixed(0)}',
                                  style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary)),
                              const SizedBox(width: 12),
                              StatusPill(status: r.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          UserRefLine(uid: r.userId),
                          const SizedBox(height: 8),
                          DetailRow(label: 'Method', value: r.method),
                          DetailRow(label: 'Requested', value: formatDateTime(r.createdAt)),
                          DetailRow(label: 'Request ID', value: r.id),
                          if (_tab == 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _busy.contains(r.id) ? null : () => _approve(r),
                                  icon: _busy.contains(r.id)
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Symbols.check_rounded, size: 18),
                                  label: const Text('Approve & credit'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _busy.contains(r.id) ? null : () => _reject(r),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                  icon: const Icon(Symbols.close_rounded, size: 18),
                                  label: const Text('Reject'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
