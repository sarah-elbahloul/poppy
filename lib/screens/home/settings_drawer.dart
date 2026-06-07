import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/providers/providers.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Drawer
//  Location: lib/screens/home/settings_drawer.dart
// ─────────────────────────────────────────────────────────────

/// The side navigation drawer for the Home screen.
/// Provides quick access to common settings, account info, and sign out.
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentThemeData;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    final auth = context.watch<AuthProvider>();
    final username = auth.displayName;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final count = context.read<EntriesProvider>().entries.length;

    return Drawer(
      backgroundColor: t.surface,
      width: AppComponentSize.drawerWidth(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accentLight,
                      border: Border.all(color: t.accent.withOpacity(0.1), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: AppTextStyles.headlineSmall(t.accent, fp).copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: AppTextStyles.titleLarge(t.textPrimary, fp),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$count ${count == 1 ? 'entry' : 'entries'} in your diary',
                        style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Divider(),
            ),

            // ── Scrollable content ────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.md,
                ),
                children: [
                  _NewEntryButton(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.write);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const _DrawerSectionHeader(label: 'Quick Access'),
                  _DrawerItem(
                    icon: AppIcons.appearance,
                    label: 'Appearance',
                    trailing: 'Custom',
                    onTap: () => _go(context, AppRoutes.appearance),
                  ),
                  _DrawerItem(
                    icon: AppIcons.security,
                    label: 'Security',
                    trailing: auth.pinEnabled ? 'PIN On' : 'Off',
                    onTap: () => _go(context, AppRoutes.security),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  const _DrawerSectionHeader(label: 'Preferences'),
                  _DrawerItem(
                    icon: AppIcons.settings,
                    label: 'All Settings',
                    onTap: () => _go(context, AppRoutes.settings),
                  ),
                  _DrawerItem(
                    icon: AppIcons.info,
                    label: 'About Poppy',
                    onTap: () => _go(context, AppRoutes.about),
                  ),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _DrawerItem(
                    icon: AppIcons.logout,
                    label: 'Sign Out',
                    isDestructive: true,
                    onTap: () => _onSignOut(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Poppy v1.0.0',
                    style: AppTextStyles.labelSmall(t.textTertiary, fp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSignOut(BuildContext context) async {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign out?', style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
        content: Text(
          'Your diary is safely stored in the cloud and will be here when you return.',
          style: AppTextStyles.bodySmallSans(t.textSecondary, fp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.textTertiary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<EntriesProvider>().clear();
      await context.read<AuthProvider>().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    }
  }
}

class _NewEntryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: t.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.accent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(AppIcons.add, color: t.accent, size: AppIconSize.sm),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Write new entry',
              style: AppTextStyles.titleSmallSans(t.accent, fp).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;
    final color = isDestructive ? AppColors.error : t.textPrimary;

    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      leading: Icon(icon, size: AppIconSize.sm, color: isDestructive ? color : t.textTertiary),
      title: Text(label, style: AppTextStyles.titleSmallSans(color, fp)),
      trailing: trailing != null
          ? Text(trailing!, style: AppTextStyles.labelLargeSans(t.textTertiary, fp))
          : !isDestructive
          ? Icon(AppIcons.chevronRight, size: AppIconSize.xs, color: t.textTertiary.withOpacity(0.5))
          : null,
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  final String label;
  const _DrawerSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.xs, top: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary, fp).copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
