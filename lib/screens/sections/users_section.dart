import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/admin_models.dart';
import '../../services/users_admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';

/// Directory of service seekers and service providers, with suspend/restore.
class UsersSection extends StatefulWidget {
  final String reviewerName;
  const UsersSection({super.key, required this.reviewerName});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  final _service = UsersAdminService();
  final _searchController = TextEditingController();
  int _tab = 0;
  String _query = '';
  final _busy = <String>{};

  /// null = all roles.
  String? get _role => switch (_tab) {
        1 => 'seeker',
        2 => 'worker',
        _ => null,
      };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleSuspend(AdminUser user) async {
    if (_busy.contains(user.uid)) return;
    String reason = '';
    if (!user.suspended) {
      final entered = await promptForReason(
        context,
        title: 'Suspend ${user.displayName}?',
        actionLabel: 'Suspend',
        hint: 'Why is this account being suspended?',
      );
      if (entered == null) return;
      reason = entered;
    }
    setState(() => _busy.add(user.uid));
    try {
      await _service.setSuspended(
        user.uid,
        !user.suspended,
        actedBy: widget.reviewerName,
        reason: reason,
      );
      UserRefLine.invalidate(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(user.suspended ? 'Account restored' : 'Account suspended')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionScaffold(
      title: 'Users',
      subtitle: 'Everyone on the platform — seekers and providers share one collection.',
      // The search box rides inside AdminFilterTabs' own Wrap. It must not be
      // a Row child alongside the chips: a Row gives its children unbounded
      // width, and the chips are themselves a Wrap, which then breaks layout
      // for this whole section.
      toolbar: AdminFilterTabs(
        labels: const ['All', 'Seekers', 'Providers'],
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
        trailing: SizedBox(
          width: 320,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name, phone, email or UID',
              prefixIcon: const Icon(Symbols.search_rounded, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Symbols.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
      ),
      child: StreamBuilder<List<AdminUser>>(
        stream: _service.watchUsers(role: _role, query: _query),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final users = snap.data!;
          if (users.isEmpty) {
            return AdminEmptyState(
              icon: Symbols.group_rounded,
              message: _query.isEmpty ? 'No users yet.' : 'No users match "$_query".',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final u = users[i];
              return AdminCard(
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: u.suspended ? AppColors.errorContainer : AppColors.secondaryContainer,
                          child: Text(
                            u.displayName[0].toUpperCase(),
                            style: AppTextStyles.labelLg.copyWith(
                              color: u.suspended ? AppColors.onErrorContainer : AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (u.isOnline && !u.suspended)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.statusGreenFg,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.displayName, style: AppTextStyles.labelLg),
                          Text(
                            '${u.roleLabel} · ${u.phone.isEmpty ? u.uid : u.phone}',
                            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CNIC', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          StatusPill(status: u.cnicStatus),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wallet', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('Rs. ${u.walletBalance.toStringAsFixed(0)}', style: AppTextStyles.labelLg),
                        ],
                      ),
                    ),
                    if (u.suspended) ...[
                      const StatusPill(status: 'suspended'),
                      const SizedBox(width: 12),
                    ],
                    _busy.contains(u.uid)
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton.icon(
                            onPressed: () => _toggleSuspend(u),
                            style: TextButton.styleFrom(
                              foregroundColor: u.suspended ? AppColors.primary : AppColors.error,
                            ),
                            icon: Icon(u.suspended ? Symbols.lock_open_rounded : Symbols.block_rounded, size: 18),
                            label: Text(u.suspended ? 'Restore' : 'Suspend'),
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
