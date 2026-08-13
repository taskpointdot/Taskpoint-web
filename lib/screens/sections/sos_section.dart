import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/admin_models.dart';
import '../../services/sos_admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';

/// Emergency SOS alerts.
///
/// The mobile app's SOS screen logs the alert with the user's coordinates
/// and then shows them their own emergency contacts to call — it can't send
/// an SMS or dial out on its own. That makes this queue the only channel
/// through which anyone at TaskPoint learns an alert was raised, so it gets
/// its own top-level section rather than being folded into Reports.
class SosSection extends StatefulWidget {
  final String reviewerName;
  const SosSection({super.key, required this.reviewerName});

  @override
  State<SosSection> createState() => _SosSectionState();
}

class _SosSectionState extends State<SosSection> {
  final _service = SosAdminService();
  int _tab = 0;
  final _busy = <String>{};

  Future<void> _resolve(SosAlert alert) async {
    final note = await promptForReason(
      context,
      title: 'Mark this alert resolved?',
      actionLabel: 'Resolve',
      hint: 'What happened / what was done?',
      required: false,
    );
    if (note == null) return;
    if (_busy.contains(alert.id)) return;
    setState(() => _busy.add(alert.id));
    try {
      await _service.resolve(alert.id, reviewedBy: widget.reviewerName, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert resolved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(alert.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'SOS Alerts',
      subtitle: 'Emergency alerts raised during active jobs. Treat unresolved alerts as urgent.',
      toolbar: AdminFilterTabs(
        labels: const ['Unresolved', 'Resolved'],
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
      child: StreamBuilder<List<SosAlert>>(
        stream: _service.watch(resolved: _tab == 1),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final alerts = snap.data!;
          if (alerts.isEmpty) {
            return AdminEmptyState(
              icon: Symbols.health_and_safety_rounded,
              message: _tab == 0 ? 'No unresolved emergency alerts.' : 'No resolved alerts yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final a = alerts[i];
              final unresolved = !a.resolved;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.soft,
                  border: unresolved ? Border.all(color: AppColors.error, width: 1.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Symbols.emergency_rounded,
                            color: unresolved ? AppColors.error : AppColors.onSurfaceVariant, fill: 1),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            unresolved ? 'UNRESOLVED EMERGENCY' : 'Resolved',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: unresolved ? AppColors.error : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(formatDateTime(a.createdAt),
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    UserRefLine(uid: a.userId, style: AppTextStyles.bodyLg),
                    const SizedBox(height: 8),
                    DetailRow(
                      label: 'Location',
                      value: a.location == null
                          ? 'Not captured (GPS unavailable)'
                          : '${a.location!.latitude.toStringAsFixed(6)}, ${a.location!.longitude.toStringAsFixed(6)}',
                    ),
                    if (a.location != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 130, top: 4),
                        child: SelectableText(
                          // Plain link rather than an embedded map: the admin
                          // app has no Maps SDK, and an operator handling an
                          // emergency wants this open in their own maps app.
                          'https://www.google.com/maps/search/?api=1&query=${a.location!.latitude},${a.location!.longitude}',
                          style: AppTextStyles.bodyMd.copyWith(color: AppColors.primary),
                        ),
                      ),
                    if (unresolved) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _busy.contains(a.id) ? null : () => _resolve(a),
                          icon: const Icon(Symbols.check_rounded, size: 18),
                          label: const Text('Mark resolved'),
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
}
