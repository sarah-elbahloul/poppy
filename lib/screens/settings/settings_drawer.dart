import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/services/export_service.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Drawer
//  Location: lib/core/widgets/settings_drawer.dart
// ─────────────────────────────────────────────────────────────

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  void _close(BuildContext context) => Navigator.pop(context);

  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(route);
  }

  // ── Export ────────────────────────────────────────────────

  Future<void> _onExport(BuildContext context) async {
    Navigator.pop(context);

    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries to export.')),
        );
      }
      return;
    }

    final t = context.poppyTheme;
    final choice = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export diary'),
        content: const Text('How would you like to export your entries?'),
        actions: [
          TextButton.icon(
            icon: Icon(AppIcons.export_, color: t.textSecondary, size: AppIconSize.xs),
            onPressed: () => Navigator.pop(context, false),
            label: Text('Plain text', style: TextStyle(color: t.textSecondary)),
          ),
          FilledButton.icon(
            icon: Icon(AppIcons.lock, color: AppColors.white, size: AppIconSize.xs),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            label: const Text('Encrypted'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      await ExportService().exportEntries(entries, encrypted: choice);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    }
  }

  // ── Import ────────────────────────────────────────────────

  Future<void> _onImport(BuildContext context) async {
    Navigator.pop(context);

    try {
      final count = await ExportService().importEntries();
      if (!context.mounted) return;

      if (count > 0) {
        await context.read<EntriesProvider>().fetchEntries();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$count ${count == 1 ? 'entry' : 'entries'} imported successfully.',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries found in the selected file.')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Import failed. Make sure you are using the correct account to decrypt this file.',
            ),
          ),
        );
      }
    }
  }

  // ── Sign out ──────────────────────────────────────────────

  Future<void> _onSignOut(BuildContext context) async {
    final t = context.poppyTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your diary will remain saved in the cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    context.read<EntriesProvider>().clear();
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
            (route) => false,
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final auth = context.watch<AuthProvider>();
    final themeData = context.watch<ThemeProvider>().currentThemeData;

    return Drawer(
      backgroundColor: t.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PoppyLogo(size: 32, prominent: false),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    auth.user?.email ?? '',
                    style: AppTextStyles.labelLargeSans(t.textTertiary),
                  ),
                ],
              ),
            ),

            _Divider(),

            const SizedBox(height: AppSpacing.xs),

            // ── Menu Items ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Item(
                    icon: AppIcons.appearance,
                    label: 'Appearance',
                    trailing: '${themeData.emoji} ${themeData.name}',
                    onTap: () => _navigateTo(context, AppRoutes.appearance),
                  ),
                  _Divider(),
                  _Item(
                    icon: AppIcons.person,
                    label: 'Account',
                    trailing: 'Email · Password',
                    onTap: () => _navigateTo(context, AppRoutes.account),
                  ),
                  _Divider(),
                  _Item(
                    icon: AppIcons.security,
                    label: 'Security',
                    trailing: 'App PIN lock',
                    onTap: () => _navigateTo(context, AppRoutes.security),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  _Item(
                    icon: AppIcons.export_,
                    label: 'Export diary',
                    trailing: 'Save backup file',
                    onTap: () => _onExport(context),
                  ),
                  _Divider(),
                  _Item(
                    icon: AppIcons.import_,
                    label: 'Import diary',
                    trailing: 'Restore from file',
                    onTap: () => _onImport(context),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  _Item(
                    icon: AppIcons.info,
                    label: 'Privacy Policy',
                    onTap: () => _navigateTo(context, AppRoutes.legalPrivacy),
                  ),
                  _Divider(),
                  _Item(
                    icon: AppIcons.info,
                    label: 'Terms of Use',
                    onTap: () => _navigateTo(context, AppRoutes.legalTerms),
                  ),
                  _Divider(),
                  _Item(
                    icon: AppIcons.info,
                    label: 'Open Source Licenses',
                    onTap: () => _navigateTo(context, AppRoutes.legalOpensource),
                  ),
                ],
              ),
            ),

            // ── Footer ──
            _Divider(),

            _Item(
              icon: AppIcons.logout,
              label: 'Sign out',
              isDestructive: true,
              onTap: () => _onSignOut(context),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                'Poppy · v1.0.0',
                style: AppTextStyles.labelMedium(t.textTertiary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final bool isDestructive;

  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final color = isDestructive ? t.accent : t.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppIconSize.sm,
              color: isDestructive ? t.accent : t.textTertiary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.titleSmallSans(color),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AppTextStyles.labelLargeSans(t.textTertiary),
              ),
            if (!isDestructive) ...[
              if (trailing != null) const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.xs,
                color: t.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg + AppIconSize.sm + AppSpacing.md,
      ),
      child: Divider(
        height: AppStroke.hairline,
        thickness: AppStroke.hairline,
        color: t.border,
      ),
    );
  }
}