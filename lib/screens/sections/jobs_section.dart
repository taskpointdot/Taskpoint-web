import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/admin_models.dart';
import '../../services/jobs_admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';

/// Every job in the marketplace, filterable by status, with a force-cancel
/// for dispute handling.
class JobsSection extends StatefulWidget {
  final String reviewerName;
  const JobsSection({super.key, required this.reviewerName});

  @override
  State<JobsSection> createState() => _JobsSectionState();
}

class _JobsSectionState extends State<JobsSection> {
  final _service = JobsAdminService();
  int _tab = 0;
  final _busy = <String>{};

  /// Index 0 is "All"; the rest map to the mobile app's status strings.
  static const _filters = <String?>[null, 'posted', 'negotiating', 'accepted', 'in_progress', 'completed', 'cancelled'];
  static const _labels = ['All', 'Posted', 'Negotiating', 'Accepted', 'In Progress', 'Completed', 'Cancelled'];

  Future<void> _cancel(AdminJob job) async {
    final reason = await promptForReason(
      context,
      title: 'Force-cancel this job?',
      actionLabel: 'Cancel job',
      hint: 'Why is this job being cancelled?',
    );
    if (reason == null) return;
    if (_busy.contains(job.id)) return;
    setState(() => _busy.add(job.id));
    try {
      await _service.cancel(job.id, actedBy: widget.reviewerName, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job cancelled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(job.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'Jobs',
      subtitle: 'All service requests, with a dispute view for anything that has gone wrong.',
      toolbar: AdminFilterTabs(
        labels: _labels,
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
      child: StreamBuilder<List<AdminJob>>(
        stream: _service.watchJobs(status: _filters[_tab]),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final jobs = snap.data!;
          if (jobs.isEmpty) {
            return const AdminEmptyState(icon: Symbols.work_rounded, message: 'No jobs in this state.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final j = jobs[i];
              final active = j.status != 'completed' && j.status != 'cancelled';
              return AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(j.categoryName, style: AppTextStyles.headlineMd),
                        ),
                        Text('Rs. ${j.effectivePrice.toStringAsFixed(0)}',
                            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
                        const SizedBox(width: 12),
                        StatusPill(status: j.statusLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      j.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Seeker', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                              UserRefLine(uid: j.seekerId),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Provider', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                              j.acceptedWorkerId == null
                                  ? Text('Not assigned yet',
                                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant))
                                  : UserRefLine(uid: j.acceptedWorkerId!),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Posted', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                              Text(formatDateTime(j.createdAt), style: AppTextStyles.bodyMd),
                            ],
                          ),
                        ),
                        if (active)
                          TextButton.icon(
                            onPressed: _busy.contains(j.id) ? null : () => _cancel(j),
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            icon: const Icon(Symbols.cancel_rounded, size: 18),
                            label: const Text('Force cancel'),
                          ),
                      ],
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
