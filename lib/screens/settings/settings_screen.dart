import 'package:flutter/material.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/services/export_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Screen
//  Location: lib/screens/settings/settings_screen.dart
// ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t          = context.poppyTheme;
    final auth       = context.watch<AuthProvider>();
    final themeData  = context.watch<ThemeProvider>().currentThemeData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: AppTextStyles.appBarTitle(t.textPrimary)),
      ),
      body: ListView(
        children: [
          // ── Email ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg,
              AppSpacing.lg, AppSpacing.sm,
            ),
            child: Text(
              auth.user?.email ?? '',
              style: AppTextStyles.settingsEmail(t.textTertiary),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // ── Appearance ────────────────────────────────
          _Section(children: [
            _Row(
              icon:     AppIcons.appearance,
              label:    'Appearance',
              sublabel: '${themeData.emoji} ${themeData.name}',
              onTap:    () => Navigator.pushNamed(context, AppRoutes.appearance),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // ── Account & Security ────────────────────────
          _Section(children: [
            _Row(
              icon:     AppIcons.person,
              label:    'Account',
              sublabel: 'Email · Password',
              onTap:    () => Navigator.pushNamed(context, AppRoutes.account),
            ),
            _Divider(),
            _Row(
              icon:     AppIcons.security,
              label:    'Security',
              sublabel: 'App PIN lock',
              onTap:    () => Navigator.pushNamed(context, AppRoutes.security),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // ── Data ──────────────────────────────────────
          _Section(children: [
            _Row(
              icon:     AppIcons.export_,
              label:    'Export diary',
              sublabel: 'Save a JSON backup',
              onTap:    () => _onExport(context),
            ),
            _Divider(),
            _Row(
              icon:     AppIcons.import_,
              label:    'Import diary',
              sublabel: 'Restore from a backup',
              onTap:    () => _onImport(context),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),
          // ── Legal ──────────────────────────────────────────
          // Note: Standard Navigator might need specific routes for these if they are separate screens.
          // In the GoRouter config, they weren't explicitly defined except as 'legal' which wasn't in the list I saw earlier.
          // Let's check the legal screen routes.
          _Section(children: [
            _Row(
              icon:     AppIcons.info,
              label:    'Privacy Policy',
              onTap:    () => Navigator.pushNamed(context, '/settings/legal/privacy'),
            ),
            _Divider(),
            _Row(
              icon:     AppIcons.info,
              label:    'Terms of Use',
              onTap:    () => Navigator.pushNamed(context, '/settings/legal/terms'),
            ),
            _Divider(),
            _Row(
              icon:     AppIcons.info,
              label:    'Open Source Licenses',
              onTap:    () => Navigator.pushNamed(context, '/settings/legal/opensource'),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),

          // ── Sign out ──────────────────────────────────
          _Section(children: [
            _Row(
              icon:          AppIcons.logout,
              label:         'Sign out',
              isDestructive: true,
              onTap:         () => _onSignOut(context),
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          Center(
            child: Text('Poppy · v1.0.0',
                style: AppTextStyles.version(t.textTertiary)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _onExport(BuildContext context) async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export.')),
      );
      return;
    }
    await ExportService().exportEntries(entries);
  }

  Future<void> _onImport(BuildContext context) async {
    try {
      final count = await ExportService().importEntries();
      if (count > 0) {
        await context.read<EntriesProvider>().fetchEntries();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count entries imported.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Import failed. Check the file format.')),
        );
      }
    }
  }

  Future<void> _onSignOut(BuildContext context) async {
    final t = context.poppyTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Sign out?'),
        content: const Text('Your diary will remain saved in the cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out',
                style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    context.read<EntriesProvider>().clear();
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
  }
}

// ── Section ────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(children: children),
    );
  }
}

// ── Settings row ───────────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  sublabel;
  final VoidCallback onTap;
  final bool isDestructive;

  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t     = context.poppyTheme;
    final color = isDestructive ? t.accent : t.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical:   AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon,
                size:  AppComponentSize.settingsIconCol,
                color: isDestructive ? t.accent : t.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.settingsRowLabel(color)),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!,
                        style: AppTextStyles.settingsRowSublabel(
                            t.textTertiary)),
                  ],
                ],
              ),
            ),
            if (!isDestructive)
              Icon(AppIcons.chevronRight,
                  size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Row divider ────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Divider(
      height:    AppStroke.hairline,
      thickness: AppStroke.hairline,
      color:     t.border,
      indent: AppSpacing.lg +
          AppComponentSize.settingsIconCol +
          AppSpacing.md,
    );
  }
}
