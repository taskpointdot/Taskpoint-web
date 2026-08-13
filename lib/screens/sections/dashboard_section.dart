import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../services/dashboard_stats_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';

/// Dashboard overview. Every card shipped as a hard-coded '—' with a
/// "Wire to …" hint; they're now real aggregate counts, and the ones that
/// represent a work queue are clickable so an admin can jump straight to
/// the module that clears them.
class DashboardSection extends StatefulWidget {
  /// Lets a metric card switch the shell's selected nav item.
  final ValueChanged<String> onOpenSection;
  const DashboardSection({super.key, required this.onOpenSection});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  final _service = DashboardStatsService();
  late Future<DashboardStats> _future = _service.loadAll();

  void _refresh() => setState(() => _future = _service.loadAll());

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'Dashboard',
      subtitle: 'Overview of what needs attention right now.',
      toolbar: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Symbols.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ),
      child: FutureBuilder<DashboardStats>(
        future: _future,
        builder: (context, snap) {
          final stats = snap.data;
          // A failed count query no longer wipes out the whole dashboard.
          // The cards still render (showing "—"), with the reason shown in a
          // banner above them — far better than the entire section vanishing
          // into one error card, which read as "the dashboard is broken".
          final failed = snap.hasError;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (failed) ...[
                  _DashboardErrorBanner(error: snap.error!),
                  const SizedBox(height: 16),
                ],
                Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  icon: Symbols.verified_user_rounded,
                  label: 'Pending CNIC Verifications',
                  value: stats?.pendingCnic,
                  failed: failed,
                  urgent: (stats?.pendingCnic ?? 0) > 0,
                  onTap: () => widget.onOpenSection('verifications'),
                ),
                _MetricCard(
                  icon: Symbols.account_balance_wallet_rounded,
                  label: 'Pending Wallet Top-Ups',
                  value: stats?.pendingTopUps,
                  failed: failed,
                  urgent: (stats?.pendingTopUps ?? 0) > 0,
                  onTap: () => widget.onOpenSection('walletTopUps'),
                ),
                _MetricCard(
                  icon: Symbols.flag_rounded,
                  label: 'Open Reports',
                  value: stats?.openReports,
                  failed: failed,
                  urgent: (stats?.openReports ?? 0) > 0,
                  onTap: () => widget.onOpenSection('reports'),
                ),
                _MetricCard(
                  icon: Symbols.emergency_rounded,
                  label: 'Unresolved SOS Alerts',
                  value: stats?.unresolvedSos,
                  failed: failed,
                  // An unattended SOS is the one number here that represents
                  // someone potentially in danger, so it always reads as
                  // critical rather than merely "needs attention".
                  critical: (stats?.unresolvedSos ?? 0) > 0,
                  onTap: () => widget.onOpenSection('sos'),
                ),
                _MetricCard(
                  icon: Symbols.group_rounded,
                  label: 'Total Active Users',
                  value: stats?.activeUsers,
                  failed: failed,
                  onTap: () => widget.onOpenSection('users'),
                ),
                _MetricCard(
                  icon: Symbols.work_rounded,
                  label: 'Jobs Today',
                  value: stats?.jobsToday,
                  failed: failed,
                  onTap: () => widget.onOpenSection('jobs'),
                ),
              ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool urgent;
  final bool critical;

  /// The count query errored, so show a dash rather than an eternal spinner.
  final bool failed;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.urgent = false,
    this.critical = false,
    this.failed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = critical
        ? AppColors.error
        : urgent
            ? AppColors.statusAmberFg
            : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
          border: critical ? Border.all(color: AppColors.error, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(height: 12),
            // Dash on failure, spinner while genuinely loading, else the count.
            failed
                ? Text('—', style: AppTextStyles.headlineLg.copyWith(color: AppColors.onSurfaceVariant))
                : value == null
                    ? const SizedBox(height: 40, width: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : Text('$value', style: AppTextStyles.headlineLg.copyWith(color: accent)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelLg),
          ],
        ),
      ),
    );
  }
}

/// Inline banner explaining why the metric counts couldn't load, shown above
/// the (dashed-out) cards instead of replacing the whole dashboard.
class _DashboardErrorBanner extends StatelessWidget {
  final Object error;
  const _DashboardErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final isPermission = message.contains('permission-denied') || message.contains('PERMISSION_DENIED');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.error_rounded, size: 20, color: AppColors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPermission
                  ? 'Could not read the dashboard counts — Firestore denied the request. '
                      'Publish the rules from the taskpoint/ project '
                      '(firebase deploy --only firestore:rules) and confirm this account has '
                      'a document under the admins collection.'
                  : 'Could not load the dashboard counts: $message',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
