import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
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
    final t         = context.poppyTheme;
    final auth      = context.watch<AuthProvider>();
    final entries   = context.watch<EntriesProvider>().entries;
    final themeData = context.watch<ThemeProvider>().currentThemeData;

    final email    = auth.user?.email ?? '';
    final initial  = email.isNotEmpty ? email[0].toUpperCase() : 'P';
    final count    = entries.length;

    return Drawer(
      backgroundColor: t.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg,
                AppSpacing.lg, AppSpacing.md,
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
                        style: AppTextStyles.titleLarge(t.accent)
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
                          email,
                          style: AppTextStyles.bodySmallSans(t.textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count ${count == 1 ? 'entry' : 'entries'}',
                          style: AppTextStyles.labelLargeSans(t.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: Icon(AppIcons.close,
                        size: AppIconSize.xs, color: t.textTertiary),
                    onPressed: () => _close(context),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: AppStroke.hairline,
                color: t.border),

            // ── Scrollable content ────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm),
                children: [

                  // ── New entry shortcut ─────────────────
                  _DrawerItem(
                    icon:    AppIcons.write,
                    label:   'New entry',
                    accent:  true,
                    onTap:   () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.write);
                    },
                  ),

                  _DrawerDivider(label: 'Quick access'),

                  // ── Most-used settings shortcuts ───────
                  _DrawerItem(
                    icon:     AppIcons.appearance,
                    label:    'Theme',
                    trailing: '${themeData.emoji} ${themeData.name}',
                    onTap:    () => _go(context, AppRoutes.appearance),
                  ),
                  _DrawerItem(
                    icon:     AppIcons.security,
                    label:    'Security',
                    trailing: auth.pinEnabled ? 'PIN on' : null,
                    onTap:    () => _go(context, AppRoutes.security),
                  ),
                  _DrawerDivider(label: 'More'),

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
                  style: AppTextStyles.labelSmall(t.textTertiary),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Sign out?',
            style: AppTextStyles.headlineSmall(t.textPrimary)),
        content: Text(
          'Your diary is safely stored in the cloud and will be '
              'here when you sign back in.',
          style: AppTextStyles.bodySmallSans(t.textSecondary)
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
                  style: AppTextStyles.titleSmallSans(labelColor)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: AppTextStyles.labelLargeSans(t.textTertiary)),
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
    final t = context.poppyTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md,
        AppSpacing.lg, AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary)
            .copyWith(letterSpacing: 0.8),
      ),
    );
  }
}