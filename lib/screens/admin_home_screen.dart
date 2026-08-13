import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../services/admin_auth_service.dart';
import 'sections/categories_section.dart';
import 'sections/cnic_section.dart';
import 'sections/dashboard_section.dart';
import 'sections/jobs_section.dart';
import 'sections/reports_section.dart';
import 'sections/sos_section.dart';
import 'sections/topups_section.dart';
import 'sections/users_section.dart';

enum _AdminSection { dashboard, verifications, walletTopUps, reports, sos, users, jobs, content }

/// Shell for the admin dashboard: a side nav (this is a web/desktop app,
/// so a persistent rail makes more sense than a bottom nav) plus a content
/// area.
///
/// Every section is now backed by a real Firestore module — they were all
/// "Coming soon" placeholders, which meant the only working part of the
/// admin app was signing in. `sos` is new: emergency alerts had no home
/// anywhere, and since the mobile app can't send SMS or dial out, this
/// dashboard is the only place an SOS becomes visible to a human.
class AdminHomeScreen extends StatefulWidget {
  final AdminProfile profile;
  final AdminAuthService authService;
  const AdminHomeScreen({super.key, required this.profile, required this.authService});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  _AdminSection _section = _AdminSection.dashboard;

  static const _navItems = [
    (_AdminSection.dashboard, Symbols.dashboard_rounded, 'Dashboard'),
    (_AdminSection.verifications, Symbols.verified_user_rounded, 'CNIC Verifications'),
    (_AdminSection.walletTopUps, Symbols.account_balance_wallet_rounded, 'Wallet Top-Ups'),
    (_AdminSection.reports, Symbols.flag_rounded, 'Reports'),
    (_AdminSection.sos, Symbols.emergency_rounded, 'SOS Alerts'),
    (_AdminSection.users, Symbols.group_rounded, 'Users'),
    (_AdminSection.jobs, Symbols.work_rounded, 'Jobs'),
    (_AdminSection.content, Symbols.category_rounded, 'Categories'),
  ];

  Future<void> _signOut() => widget.authService.signOut();

  /// Lets the dashboard's metric cards jump to the module that clears them.
  void _openNamedSection(String name) {
    final target = switch (name) {
      'verifications' => _AdminSection.verifications,
      'walletTopUps' => _AdminSection.walletTopUps,
      'reports' => _AdminSection.reports,
      'sos' => _AdminSection.sos,
      'users' => _AdminSection.users,
      'jobs' => _AdminSection.jobs,
      'content' => _AdminSection.content,
      _ => _AdminSection.dashboard,
    };
    setState(() => _section = target);
  }

  @override
  Widget build(BuildContext context) {
    final reviewer = widget.profile.name.isEmpty ? widget.profile.email : widget.profile.name;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _SideNav(
            profile: widget.profile,
            current: _section,
            items: _navItems,
            onSelect: (s) => setState(() => _section = s),
            onSignOut: _signOut,
          ),
          Expanded(
            // Keyed so switching sections rebuilds from scratch rather than
            // letting one module's filter state bleed into the next.
            child: KeyedSubtree(
              key: ValueKey(_section),
              child: switch (_section) {
                _AdminSection.dashboard => DashboardSection(onOpenSection: _openNamedSection),
                _AdminSection.verifications => CnicSection(reviewerName: reviewer),
                _AdminSection.walletTopUps => TopUpsSection(reviewerName: reviewer),
                _AdminSection.reports => ReportsSection(reviewerName: reviewer),
                _AdminSection.sos => SosSection(reviewerName: reviewer),
                _AdminSection.users => UsersSection(reviewerName: reviewer),
                _AdminSection.jobs => JobsSection(reviewerName: reviewer),
                _AdminSection.content => const CategoriesSection(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final AdminProfile profile;
  final _AdminSection current;
  final List<(_AdminSection, IconData, String)> items;
  final ValueChanged<_AdminSection> onSelect;
  final VoidCallback onSignOut;

  const _SideNav({required this.profile, required this.current, required this.items, required this.onSelect, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    // Must be a Material, not a plain Container(color:). The nav's ListTiles
    // paint their selection highlight and ink splash onto the nearest
    // Material ancestor; a ColoredBox (what Container(color:) creates) sitting
    // between them and the Scaffold's Material hides those effects, which
    // Flutter turns into a hard assertion during build. That assertion fired
    // on the very first build of this screen after login and aborted it —
    // which is why the whole dashboard showed up blank.
    return Material(
      color: AppColors.surfaceContainerLowest,
      child: SizedBox(
        width: 260,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  const Icon(Symbols.shield_person_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Expanded(child: Text('TaskPoint Admin', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final (section, icon, label) in items)
                    ListTile(
                      selected: section == current,
                      selectedTileColor: AppColors.primaryContainer.withOpacity(0.12),
                      leading: Icon(icon, color: section == current ? AppColors.primary : AppColors.onSurfaceVariant),
                      title: Text(label, style: AppTextStyles.bodyLg.copyWith(color: section == current ? AppColors.primary : AppColors.onSurface, fontWeight: section == current ? FontWeight.w600 : FontWeight.w400)),
                      onTap: () => onSelect(section),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: AppColors.secondaryContainer, child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSecondaryContainer))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name, style: AppTextStyles.labelLg, overflow: TextOverflow.ellipsis),
                        Text(profile.role, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Symbols.logout_rounded, color: AppColors.error), tooltip: 'Sign out', onPressed: onSignOut),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

