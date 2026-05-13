import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
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
    final t         = context.poppyTheme;
    final auth      = context.watch<AuthProvider>();
    final themeData = context.watch<ThemeProvider>().currentThemeData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings',
            style: AppTextStyles.appBarTitle(t.textPrimary)),
      ),
      body: ListView(
        children: [
          // Account email
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

          // Appearance
          _Section(children: [
            _Row(
              icon:     AppIcons.appearance,
              label:    'Appearance',
              sublabel: '${themeData.emoji} ${themeData.name}',
              onTap:    () => Navigator.of(context)
                  .pushNamed(AppRoutes.appearance),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // Account & Security
          _Section(children: [
            _Row(
              icon:     AppIcons.person,
              label:    'Account',
              sublabel: 'Email · Password',
              onTap:    () => Navigator.of(context)
                  .pushNamed(AppRoutes.account),
            ),
            _RowDivider(),
            _Row(
              icon:     AppIcons.security,
              label:    'Security',
              sublabel: 'App PIN lock',
              onTap:    () => Navigator.of(context)
                  .pushNamed(AppRoutes.security),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // Data
          _Section(children: [
            _Row(
              icon:     AppIcons.export_,
              label:    'Export diary',
              sublabel: 'Save a .poppy backup file',
              onTap:    () => _onExport(context),
            ),
            _RowDivider(),
            _Row(
              icon:     AppIcons.import_,
              label:    'Import diary',
              sublabel: 'Restore from a .poppy or .json file',
              onTap:    () => _onImport(context),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // Legal
          _Section(children: [
            _Row(
              icon:     AppIcons.privacyPolicy,
              label:    'Privacy Policy',
              onTap:    () => Navigator.of(context)
                  .pushNamed(AppRoutes.legalPrivacy),
            ),
            _RowDivider(),
            _Row(
              icon:     AppIcons.Tos,
              label:    'Terms of Use',
              onTap:    () => Navigator.of(context)
                  .pushNamed(AppRoutes.legalTerms),
            ),
            _RowDivider(),
            _Row(
              icon:     AppIcons.Osl,
              label:    'Open Source Licenses',
              onTap:    () => Navigator.of(context)
                  .pushNamed(AppRoutes.legalOpensource),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // Sign out
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

  // ── Export ────────────────────────────────────────────────

  Future<void> _onExport(BuildContext context) async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export.')),
      );
      return;
    }
    try {
      await ExportService().exportEntries(entries);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    }
  }

  // ── Import ────────────────────────────────────────────────
  // After import, fetchEntries() is called to sync the
  // in-memory list. Without this, edits to imported entries
  // will silently fail because the provider holds stale data.

  Future<void> _onImport(BuildContext context) async {
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
          const SnackBar(
              content: Text('No entries found in the selected file.')),
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
              content: Text('Import failed. Check the file format.')),
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
        title:   const Text('Sign out?'),
        content: const Text(
            'Your diary will remain saved in the cloud.'),
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
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login, (route) => false,
      );
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

// ── Row ────────────────────────────────────────────────────────

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
          horizontal: AppSpacing.md, vertical: AppSpacing.md,
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

class _RowDivider extends StatelessWidget {
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