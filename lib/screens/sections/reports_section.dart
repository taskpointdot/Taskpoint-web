import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/admin_models.dart';
import '../../services/reports_admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';

/// Moderation queue for user-submitted reports — both app-wide problem
/// reports and complaints against a specific service provider.
class ReportsSection extends StatefulWidget {
  final String reviewerName;
  const ReportsSection({super.key, required this.reviewerName});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  final _service = ReportsAdminService();
  int _tab = 0;
  final _busy = <String>{};

  static const _statuses = ['open', 'resolved', 'dismissed'];

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

  Future<void> _close(AdminReport report, {required bool resolved}) async {
    final note = await promptForReason(
      context,
      title: resolved ? 'Resolve this report?' : 'Dismiss this report?',
      actionLabel: resolved ? 'Resolve' : 'Dismiss',
      hint: 'What action was taken? (optional)',
      required: false,
    );
    if (note == null) return;
    await _run(
      report.id,
      () => resolved
          ? _service.resolve(report.id, reviewedBy: widget.reviewerName, note: note)
          : _service.dismiss(report.id, reviewedBy: widget.reviewerName, note: note),
      resolved ? 'Report resolved' : 'Report dismissed',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'Reports',
      subtitle: 'Disputes and complaints raised from the mobile app.',
      toolbar: AdminFilterTabs(
        labels: const ['Open', 'Resolved', 'Dismissed'],
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
      child: StreamBuilder<List<AdminReport>>(
        stream: _service.watchByStatus(_statuses[_tab]),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final reports = snap.data!;
          if (reports.isEmpty) {
            return AdminEmptyState(
              icon: Symbols.flag_rounded,
              message: _tab == 0 ? 'No open reports. ' : 'Nothing here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final r = reports[i];
              return AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          r.isAgainstWorker ? Symbols.person_alert_rounded : Symbols.support_agent_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _humanReason(r.reason),
                            style: AppTextStyles.headlineMd,
                          ),
                        ),
                        StatusPill(status: r.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (r.details.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: SelectableText(r.details, style: AppTextStyles.bodyMd),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reported by', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                              UserRefLine(uid: r.reporterId),
                            ],
                          ),
                        ),
                        if (r.isAgainstWorker)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reported provider',
                                    style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                                UserRefLine(uid: r.targetUserId!),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Submitted', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                              Text(formatDateTime(r.createdAt), style: AppTextStyles.bodyMd),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (r.evidenceUrl != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => showImagePreview(context, r.evidenceUrl!, 'Evidence'),
                        icon: const Icon(Symbols.image_rounded, size: 18),
                        label: const Text('View evidence'),
                      ),
                    ],
                    if (_tab == 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busy.contains(r.id) ? null : () => _close(r, resolved: false),
                            child: const Text('Dismiss'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _busy.contains(r.id) ? null : () => _close(r, resolved: true),
                            icon: const Icon(Symbols.check_rounded, size: 18),
                            label: const Text('Resolve'),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy.contains(r.id)
                              ? null
                              : () => _run(r.id, () => _service.reopen(r.id), 'Report reopened'),
                          child: const Text('Reopen'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// The worker-report path stores an enum name (`inappropriateBehavior`),
  /// while "Report a Problem" stores an already-human string. Normalise the
  /// camelCase one so the queue doesn't show raw identifiers.
  String _humanReason(String reason) {
    if (reason.isEmpty) return 'Report';
    if (reason.contains(' ')) return reason;
    final spaced = reason.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
