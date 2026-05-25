import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/services/export_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Screen (full hub)
//  Location: lib/screens/settings/settings_screen.dart
//
//  This is the canonical settings destination. The drawer links
//  here for "All Settings" and also shortcuts some sub-screens.
//
//  SECTIONS
//  ─────────
//  Personalisation  → Appearance (theme)
//  Account          → email, password
//  Security         → PIN, biometrics, auto-lock
//  Notifications    → writing reminders (stub, future)
//  Data             → export (plain/encrypted), import
//  Support          → feedback, about
//  Legal            → privacy, terms, open-source
//  Danger zone      → sign out, delete account
// ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t    = context.poppyTheme;
    final auth = context.watch<AuthProvider>();
    final td   = context.watch<ThemeProvider>().currentThemeData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings',
            style: AppTextStyles.titleLarge(t.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [

          // ── Profile chip ─────────────────────────────────
          _ProfileChip(email: auth.user?.email ?? ''),

          const SizedBox(height: AppSpacing.lg),

          // ── Personalisation ──────────────────────────────
          _SectionLabel('Personalisation'),
          _Card(children: [
            _SettingsRow(
              icon:     AppIcons.appearance,
              label:    'Theme',
              value:    '${td.emoji} ${td.name}',
              onTap:    () => _push(context, AppRoutes.appearance),
            ),
          ]),

          // ── Account & Security ───────────────────────────
          _SectionLabel('Account & Security'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.person,
              label: 'Account',
              value: 'Email · Password',
              onTap: () => _push(context, AppRoutes.account),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.security,
              label: 'Security',
              value: 'PIN lock · Biometrics',
              onTap: () => _push(context, AppRoutes.security),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.emailUnread,
              label: 'Notifications',
              value: 'Writing reminders',
              onTap: () => _push(context, AppRoutes.notifications),
            ),
          ]),

          // ── Data ─────────────────────────────────────────
          _SectionLabel('Data'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.export_,
              label: 'Export diary',
              value: 'Download a backup',
              onTap: () => _onExport(context),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.import_,
              label: 'Import diary',
              value: 'Restore from a file',
              onTap: () => _onImport(context),
            ),
          ]),

          // ── Support ──────────────────────────────────────
          _SectionLabel('Support'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.info,
              label: 'Send feedback',
              value: 'Bugs · Ideas · Questions',
              onTap: () => _onFeedback(context),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.checkCircle,
              label: 'About Poppy',
              value: 'Version · Licenses',
              onTap: () => _push(context, AppRoutes.about),
            ),
          ]),

          // ── Legal ─────────────────────────────────────────
          _SectionLabel('Legal'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.privacyPolicy,
              label: 'Privacy Policy',
              onTap: () => _push(context, AppRoutes.legalPrivacy),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.Tos,
              label: 'Terms of Use',
              onTap: () => _push(context, AppRoutes.legalTerms),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.Osl,
              label: 'Open Source Licenses',
              onTap: () => _push(context, AppRoutes.legalOpensource),
            ),
          ]),

          // ── Danger zone ───────────────────────────────────
          _SectionLabel('Account actions'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.logout,
              label: 'Sign out',
              onTap: () => _onSignOut(context),
            ),
            _RowLine(),
            _SettingsRow(
              icon:          AppIcons.delete,
              label:         'Delete account',
              value:         'Removes all data permanently',
              isDestructive: true,
              onTap:         () => _onDeleteAccount(context),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────

  void _push(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);

  // ── Export ────────────────────────────────────────────────

  Future<void> _onExport(BuildContext context) async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export.')),
      );
      return;
    }

    final t      = context.poppyTheme;
    final choice = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Export diary',
            style: AppTextStyles.headlineSmall(t.textPrimary)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: AppSpacing.sm),
            _ExportOption(
              icon:  AppIcons.export_,
              title: 'Plain text',
              desc:  'Readable by anyone. No password needed.',
              color: AppColors.error,
            ),
            SizedBox(height: AppSpacing.sm),
            _ExportOption(
              icon:  AppIcons.lock,
              title: 'Encrypted',
              desc:  'Requires your Poppy password to import.',
              color: AppColors.error,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Plain text',
                style: TextStyle(color: t.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
            FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Encrypted'),
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
          const SnackBar(
              content: Text('Export failed. Please try again.')),
        );
      }
    }
  }

  // ── Import ────────────────────────────────────────────────

  Future<void> _onImport(BuildContext context) async {
    try {
      final count = await ExportService().importEntries();
      if (!context.mounted) return;
      if (count > 0) {
        await context.read<EntriesProvider>().fetchEntries();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count '
                  '${count == 1 ? 'entry' : 'entries'} imported.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No entries found in the selected file.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException
                ? e.message
                : 'Import failed. Make sure the file is a valid '
                'Poppy export from the same account.'),
          ),
        );
      }
    }
  }

  // ── Feedback ──────────────────────────────────────────────

  Future<void> _onFeedback(BuildContext context) async {
    const email = 'hello@poppy.app';
    final t     = context.poppyTheme;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Send feedback',
            style: AppTextStyles.headlineSmall(t.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We read every message. Bugs, ideas, or just to say hi — '
                  'all welcome.',
              style: AppTextStyles.bodySmallSans(t.textSecondary)
                  .copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                    const ClipboardData(text: email));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Email address copied.')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: t.accentLight,
                  borderRadius:
                  BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: t.accent.withOpacity(0.25),
                    width: AppStroke.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.email,
                        size: AppIconSize.xs, color: t.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(email,
                          style: AppTextStyles.bodySmallSans(
                              t.accent)),
                    ),
                    Icon(AppIcons.copy,
                        size: AppIconSize.xs,
                        color: t.textTertiary),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: TextStyle(color: t.textTertiary)),
          ),
        ],
      ),
    );
  }

  // ── Sign out ──────────────────────────────────────────────

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
          'Your diary is safely stored in the cloud. '
              'You can sign back in any time.',
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
            style:
            FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    context.read<EntriesProvider>().clear();
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  // ── Delete account ────────────────────────────────────────
  //  Two-step: warn + offer export → then type DELETE to confirm.

  Future<void> _onDeleteAccount(BuildContext context) async {
    final t       = context.poppyTheme;
    final entries = context.read<EntriesProvider>().entries;

    // ─── Step 1: Warning + export offer ───
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(children: [
          Icon(AppIcons.warning,
              color: t.accent, size: AppIconSize.sm),
          const SizedBox(width: AppSpacing.sm),
          Text('Delete account',
              style: AppTextStyles.headlineSmall(t.textPrimary)),
          Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: t.textTertiary)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This permanently deletes your Poppy account and every '
                  'diary entry you have written. It cannot be undone.',
              style: AppTextStyles.bodySmallSans(t.textSecondary)
                  .copyWith(height: 1.6),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: t.accentLight,
                  borderRadius:
                  BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: t.accent.withOpacity(0.3),
                    width: AppStroke.hairline,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.export_,
                        size: AppIconSize.xs, color: t.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You have ${entries.length} '
                            '${entries.length == 1 ? 'entry' : 'entries'}. '
                            'Export a backup before you go — once deleted, '
                            'your entries are gone forever.',
                        style: AppTextStyles.labelLargeSans(t.accent)
                            .copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          if (entries.isNotEmpty)
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _onExport(context);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: t.accent, width: AppStroke.thin),
              ),
              child: Text('Export first',
                  style: TextStyle(color: t.accent)),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
            FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    // ─── Step 2: Type DELETE ───
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountConfirmDialog(),
    );

    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final ok   = await auth.deleteAccount();
    if (!context.mounted) return;

    if (ok) {
      context.read<EntriesProvider>().clear();
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Your account has been deleted.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ??
              'Could not delete account. Please try again.'),
        ),
      );
    }
  }
}

// ── Profile chip ──────────────────────────────────────────────

class _ProfileChip extends StatelessWidget {
  final String email;
  const _ProfileChip({required this.email});

  @override
  Widget build(BuildContext context) {
    final t       = context.poppyTheme;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'P';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md,
        AppSpacing.lg, 0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
          Border.all(color: t.border, width: AppStroke.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: t.accentLight,
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
                  Text(email,
                      style:
                      AppTextStyles.bodySmallSans(t.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Signed in',
                      style: AppTextStyles.labelLargeSans(
                          t.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Export option ─────────────────────────────────────────────

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   desc;
  final Color    color;
  const _ExportOption({
    required this.icon, required this.title,
    required this.desc, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: AppIconSize.xs, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTextStyles.titleSmallSans(t.textPrimary)),
              Text(desc,
                  style: AppTextStyles.labelLargeSans(t.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg,
        AppSpacing.lg, AppSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary)
            .copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

// ── Card container ────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
        Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(children: children),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  value;
  final bool     isDestructive;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t     = context.poppyTheme;
    final color = isDestructive ? AppColors.error : t.textPrimary;

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
            Icon(
              icon,
              size:  AppComponentSize.settingsIconCol,
              color: isDestructive ? AppColors.error : t.textTertiary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.titleSmallSans(color)),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(value!,
                        style: AppTextStyles.labelLargeSans(
                            t.textTertiary)),
                  ],
                ],
              ),
            ),
            Icon(AppIcons.chevronRight,
                size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Row divider ───────────────────────────────────────────────

class _RowLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Divider(
      height:    AppStroke.hairline,
      thickness: AppStroke.hairline,
      color:     t.border,
      indent: AppSpacing.md +
          AppComponentSize.settingsIconCol +
          AppSpacing.md,
    );
  }
}


class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {

  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        'Are you absolutely sure?',
        style: AppTextStyles.headlineSmall(t.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type DELETE in capitals to confirm.',
            style: AppTextStyles.bodySmallSans(t.textSecondary),
          ),

          const SizedBox(height: AppSpacing.md),

          Container(
            decoration: BoxDecoration(
              color: t.background,
              borderRadius:
              BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: t.border,
                width: AppStroke.hairline,
              ),
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: AppTextStyles.bodyMedium(t.textPrimary),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle:
                AppTextStyles.bodyMedium(t.textTertiary),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: t.textTertiary),
          ),
        ),

        FilledButton(
          onPressed: _ctrl.text == 'DELETE'
              ? () => Navigator.pop(context, true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            disabledBackgroundColor:
            t.accent.withOpacity(0.3),
          ),
          child: const Text('Delete my account'),
        ),
      ],
    );
  }
}