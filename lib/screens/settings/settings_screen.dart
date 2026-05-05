import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/services/export_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Screen
//  Location: lib/screens/settings/settings_screen.dart
//
//  Top-level settings menu. Clean list of destinations —
//  no crowding. Each row navigates to a focused sub-screen.
// ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: t.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings',
            style: TextStyle(fontSize: 18, color: t.textPrimary)),
      ),
      body: ListView(
        children: [
          // ── Account info ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLG, kSpaceLG, kSpaceLG, kSpaceSM),
            child: Text(
              auth.user?.email ?? '',
              style: TextStyle(fontSize: 13, color: t.textTertiary),
            ),
          ),

          const SizedBox(height: kSpaceXS),

          // ── Appearance ────────────────────────────────────
          _Section(
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                sublabel: context
                    .watch<_ThemeNameHelper>()
                    .name,
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),

          const SizedBox(height: kSpaceSM),

          // ── Account & Security ────────────────────────────
          _Section(
            children: [
              _SettingsRow(
                icon: Icons.person_outline,
                label: 'Account',
                sublabel: 'Email · Password',
                onTap: () => context.push('/settings/account'),
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.lock_outline,
                label: 'Security',
                sublabel: 'App PIN lock',
                onTap: () => context.push('/settings/security'),
              ),
            ],
          ),

          const SizedBox(height: kSpaceSM),

          // ── Data ──────────────────────────────────────────
          _Section(
            children: [
              _SettingsRow(
                icon: Icons.upload_outlined,
                label: 'Export diary',
                sublabel: 'Save a JSON backup',
                onTap: () => _onExport(context),
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.download_outlined,
                label: 'Import diary',
                sublabel: 'Restore from a backup',
                onTap: () => _onImport(context),
              ),
            ],
          ),

          const SizedBox(height: kSpaceSM),

          // ── Sign out ──────────────────────────────────────
          _Section(
            children: [
              _SettingsRow(
                icon: Icons.logout,
                label: 'Sign out',
                isDestructive: true,
                onTap: () => _onSignOut(context),
              ),
            ],
          ),

          const SizedBox(height: kSpaceXL),

          // ── App version ───────────────────────────────────
          Center(
            child: Text(
              'Poppy · v1.0.0',
              style: TextStyle(fontSize: 11, color: t.textTertiary),
            ),
          ),
          const SizedBox(height: kSpaceLG),
        ],
      ),
    );
  }

  Future<void> _onExport(BuildContext context) async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entries to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ExportService().exportEntries(entries);
  }

  Future<void> _onImport(BuildContext context) async {
    final t = context.poppyTheme;
    try {
      final count = await ExportService().importEntries();
      if (count > 0) {
        await context.read<EntriesProvider>().fetchEntries();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count entries imported.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed. Check the file format.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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
            child: Text('Cancel',
                style: TextStyle(color: t.textSecondary)),
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
    if (context.mounted) context.go('/login');
  }
}

// ── Helper to read current theme name without extra imports ───

class _ThemeNameHelper extends StatelessWidget {
  final String name;
  const _ThemeNameHelper({required this.name});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Section container ──────────────────────────────────────────

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kSpaceLG),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(kRadiusMD),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

// ── Settings row ───────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final color = isDestructive ? t.accent : t.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMD),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMD,
          vertical: kSpaceMD,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDestructive ? t.accent : t.textTertiary),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isDestructive)
              Icon(Icons.chevron_right, size: 18, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Hairline divider between rows ─────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: t.border,
      indent: kSpaceLG + 20 + kSpaceMD,
    );
  }
}