import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/providers/providers.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Drawer
//  Location: lib/screens/settings/settings_drawer.dart
//
//  PURPOSE: Quick-access sidebar opened from the ☰ button on
//  HomeScreen. It is NOT a second settings screen — it shows
//  profile context, entry stats, and direct shortcuts to the
//  most common destinations. The full Settings screen
//  (AppRoutes.settings) is where all configuration lives.
//
//  STRUCTURE:
//    Header  — avatar initial, email, entry count
//    Quick write — "New entry" shortcut
//    Shortcuts — Appearance, Security, Export (most-used)
//    All Settings — link to full settings hub
//    Footer — version, sign out
// ─────────────────────────────────────────────────────────────

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  void _close(BuildContext context) => Navigator.pop(context);

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final t         = context.watch<ThemeProvider>().currentThemeData;
    final fp        = context.watch<ThemeProvider>().currentFontPairData;
    final auth      = context.watch<AuthProvider>();
    final username = context.read<AuthProvider>().displayName;
    final initial   = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final count     = context.read<EntriesProvider>().entries.length;

    return Drawer(
      backgroundColor: t.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accentLight,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: AppTextStyles.titleLarge(t.accent, fp)
                            .copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: AppTextStyles.titleLarge(t.textPrimary, fp),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count ${count == 1 ? 'entry' : 'entries'}',
                          style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(
                height: AppStroke.hairline,
                thickness: AppStroke.hairline,
                color: t.border
            ),

            // ── Scrollable content ────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [

                  // ── New entry shortcut ─────────────────
                  _DrawerItem(
                    icon:    AppIcons.add,
                    label:   'New entry',
                    accent:  true,
                    onTap:   () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.write);
                    },
                  ),

                  const _DrawerDivider(label: 'Quick access'),

                  // ── Most-used settings shortcuts ───────
                  _DrawerItem(
                    icon:     AppIcons.appearance,
                    label:    'Appearance',
                    trailing: 'Custom',
                    onTap:    () => _go(context, AppRoutes.appearance),
                  ),
                  _DrawerItem(
                    icon:     AppIcons.security,
                    label:    'Security',
                    trailing: auth.pinEnabled ? 'PIN on' : null,
                    onTap:    () => _go(context, AppRoutes.security),
                  ),
                  const _DrawerDivider(label: 'More'),

                  // ── Full settings hub ──────────────────
                  _DrawerItem(
                    icon:    AppIcons.settings,
                    label:   'All settings',
                    onTap:   () => _go(context, AppRoutes.settings),
                  ),
                  _DrawerItem(
                    icon:  AppIcons.info,
                    label: 'About Poppy',
                    onTap: () => _go(context, AppRoutes.about),
                  ),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────
            Divider(height: 1, thickness: AppStroke.hairline,
                color: t.border),

            _DrawerItem(
              icon:          AppIcons.logout,
              label:         'Sign out',
              isDestructive: true,
              onTap:         () => _onSignOut(context),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Center(
                child: Text(
                  'Poppy · v1.0.0',
                  style: AppTextStyles.labelSmall(t.textTertiary, fp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSignOut(BuildContext context) async {
    final t         = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Sign out?',
            style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
        content: Text(
          'Your diary is safely stored in the cloud and will be '
              'here when you sign back in.',
          style: AppTextStyles.bodySmallSans(t.textSecondary, fp)
              .copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: t.textTertiary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<EntriesProvider>().clear();
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }
}

// ── Private widgets ────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  trailing;
  final bool     isDestructive;
  final bool     accent;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final t          = context.poppyTheme;
    final labelColor = isDestructive
        ? AppColors.error
        : accent
        ? t.accent
        : t.textPrimary;
    final iconColor  = isDestructive
        ? AppColors.error
        : accent
        ? t.accent
        : t.textTertiary;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.sm, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.titleSmallSans(labelColor, fp)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (!isDestructive)
              Icon(AppIcons.chevronRight,
                  size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  final String label;
  const _DrawerDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md,
        AppSpacing.lg, AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary, fp).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}