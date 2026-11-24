import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/controllers/profile_providers.dart';
import '../theme/app_theme.dart';

class _NavItem {
  final String label;
  final String path;
  final IconData icon;

  const _NavItem(this.label, this.path, this.icon);
}

const _userItems = [
  _NavItem('Home', '/home', Icons.home_outlined),
  _NavItem('Jobs', '/jobs', Icons.work_outline),
  _NavItem('Applied jobs', '/applied', Icons.assignment_outlined),
  _NavItem('History', '/history', Icons.history),
  _NavItem('Account', '/account', Icons.person_outline),
];

const _adminItems = [
  _NavItem('Verifications', '/admin', Icons.verified_user_outlined),
  _NavItem('Student requests', '/admin/students', Icons.school_outlined),
  _NavItem('Jobs to review', '/admin/jobs', Icons.work_outline),
  _NavItem('Disputes', '/admin/disputes', Icons.gavel),
  _NavItem('Account', '/account', Icons.person_outline),
];

/// Friendly name for a role value stored in the database.
String roleLabel(String role) {
  switch (role) {
    case 'student':
      return 'Student';
    case 'poster':
      return 'Poster';
    case 'admin':
      return 'Administrator';
    default:
      return role;
  }
}

/// Wraps every signed-in page: a sidebar on wide screens, a bottom bar on
/// narrow ones (phones).
class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const AppShell({required this.location, required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    final items = profile?.role == 'admin' ? _adminItems : _userItems;
    final selected = items.indexWhere((item) => item.path == location);
    final wide = MediaQuery.sizeOf(context).width >= 800;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              items: items,
              selected: selected,
              name: profile?.fullName ?? '',
              role: profile == null ? '' : roleLabel(profile.role),
              onLogout: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        // No item is highlighted on pages like a job's details.
        selectedIndex: selected < 0 ? 0 : selected,
        indicatorColor: selected < 0 ? Colors.transparent : sunYellow,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) => context.go(items[i].path),
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              label: item.label,
              tooltip: item.label,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selected;
  final String name;
  final String role;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.name,
    required this.role,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      color: grassGreen,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: sunYellow,
                    child: Icon(Icons.school, color: deepGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TaskMate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Central Mindanao University',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: sunYellow, thickness: 2, height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '...' : name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    role,
                    style: const TextStyle(color: sunYellow, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SideItem(
                      label: items[i].label,
                      icon: items[i].icon,
                      selected: i == selected,
                      onTap: () => context.go(items[i].path),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: _SideItem(
                label: 'Log out',
                icon: Icons.logout,
                selected: false,
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SideItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? deepGreen : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? sunYellow : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
