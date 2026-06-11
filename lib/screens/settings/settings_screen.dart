import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/core/widgets/widgets.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/services/export_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Screen
//  Location: lib/screens/settings/settings_screen.dart
// ─────────────────────────────────────────────────────────────

/// The central settings hub of the application.
/// 
/// Organizes all configuration options into logical sections:
/// - Personalization (Appearance)
/// - Account & Security
/// - Data Management (Export/Import)
/// - Support & Legal
/// - Danger Zone (Sign out/Delete account)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final td   = context.watch<ThemeProvider>().currentThemeData;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Scaffold(
      backgroundColor: td.background,
      appBar: AppBar(
        backgroundColor: td.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: td.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings',
            style: AppTextStyles.titleLarge(td.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          // ── Profile chip ─────────────────────────────────
          _ProfileChip(email: auth.user?.email ?? ''),

          const SizedBox(height: AppSpacing.lg),

          // ── Personalisation ──────────────────────────────
          const _SectionLabel('Personalisation'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.appearance,
              label: 'Appearance',
              value: 'Fonts · Colors',
              onTap: () => _push(context, AppRoutes.appearance),
            ),
            _RowLine(),
            _SettingsRow(
              icon:  AppIcons.tagOutline,
              label: 'Entry Tags',
              value: 'Names · Colors',
              onTap: () => _push(context, AppRoutes.tags),
            ),
          ]),

          // ── Account & Security ───────────────────────────
          const _SectionLabel('Account & Security'),
          _Card(children: [
            _SettingsRow(
              icon:  AppIcons.person,
              label: 'Account',
              value: 'Name · Email · Password',
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
          const _SectionLabel('Data'),
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
          const _SectionLabel('Support'),
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
          const _SectionLabel('Legal'),
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
          const _SectionLabel('Account actions'),
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

  // ─── Navigation ───

  void _push(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);

  // ─── Actions ───

  /// Initiates the diary export process, offering choice between plain and encrypted files.
  Future<void> _onExport(BuildContext context) async {
    final entries = context.read<EntriesProvider>().entries;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    if (entries.isEmpty) {
      AppSnackbar.warning(context, 'No entries to export.');
      return;
    }

    final t = context.poppyTheme;

    final choice = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Export diary',
            style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExportOption(
              icon:  AppIcons.lock,
              title: 'Encrypted',
              desc:  'Entries are scrambled. Only importable back into this Poppy account.',
              color: t.accent,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color:        AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border:       Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                  width: AppStroke.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ExportOption(
                    icon:  AppIcons.export_,
                    title: 'Plain text',
                    desc:  'Readable by anyone who opens the file.',
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(AppIcons.info,
                          size: 13, color: AppColors.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Your diary entries will be unprotected. '
                              'Only use if you need to open the file outside Poppy.',
                          style: AppTextStyles.labelSmall(AppColors.error, fp)
                              .copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: t.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plain text',
                style: TextStyle(color: AppColors.error)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Encrypted'),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    try {
      final svc      = ExportService();
      final savedPath = await svc.exportEntries(entries, encrypted: choice);

      if (!context.mounted) return;

      if (savedPath != null) {
        final filename = savedPath.split('/').last;
        AppSnackbar.success(
          context,
          'Saved to Downloads/$filename',
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => svc.shareExportFile(savedPath),
          ),
        );
      } else {
        AppSnackbar.info(context, 'Export ready to share.');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, 'Export failed. Please try again.');
      }
    }
  }

  /// Handles the import of journal entries from a file.
  Future<void> _onImport(BuildContext context) async {
    final svc = ExportService();
    final t   = context.poppyTheme;

    late ImportPreview preview;
    try {
      preview = await svc.previewImport();
    } on ImportCancelledException {
      return;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          e is FormatException
              ? e.message
              : 'Could not read the file. Is it a valid Poppy export?',
        );
      }
      return;
    }

    if (!context.mounted) return;

    final entryWord = preview.entryCount == 1 ? 'entry' : 'entries';
    final fp = context.read<ThemeProvider>().currentFontPairData;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Import entries?',
            style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color:        t.accentLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border:       Border.all(
                  color: t.accent.withValues(alpha: 0.2),
                  width: AppStroke.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.import_,
                          size: AppIconSize.xs, color: t.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${preview.entryCount} $entryWord found',
                        style: AppTextStyles.titleSmallSans(t.textPrimary, fp),
                      ),
                    ],
                  ),
                  if (preview.exportedAt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Text(
                        'Exported ${preview.exportedAtFormatted}',
                        style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      preview.isEncrypted ? 'Encrypted backup' : 'Plain text backup',
                      style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'New entries will be added. Existing entries with the same ID will be skipped.',
              style: AppTextStyles.bodySmallSans(t.textSecondary, fp)
                  .copyWith(height: 1.5),
            ),
          ],
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
            child: Text('Import ${preview.entryCount} $entryWord'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final count = await svc.commitImport(preview);
      if (!context.mounted) return;
      if (count > 0) {
        await context.read<EntriesProvider>().fetchEntries();
        if (context.mounted) {
          AppSnackbar.success(
            context,
            '$count ${count == 1 ? 'entry' : 'entries'} imported.',
          );
        }
      } else {
        AppSnackbar.info(context, 'No new entries found in the selected file.');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          e is FormatException
              ? e.message
              : 'Import failed. Make sure the file is a valid Poppy export from the same account.',
        );
      }
    }
  }

  Future<void> _onFeedback(BuildContext context) async {
    const email = 'sa.albahloul@gmail.com'; // todo: change this to actual email
    final t     = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Send feedback', style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We read every message. Bugs, ideas, or just to say hi — '
                  'all welcome.',
              style: AppTextStyles.bodySmallSans(t.textSecondary, fp)
                  .copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                    const ClipboardData(text: email));
                Navigator.pop(ctx);
                AppSnackbar.info(context, 'Email address copied.');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical:   AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: t.accentLight,
                  borderRadius:
                  BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: t.accent.withValues(alpha: 0.25),
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
                              t.accent, fp)),
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
          'Your diary is safely stored in the cloud. '
              'You can sign back in any time.',
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

  Future<void> _onDeleteAccount(BuildContext context) async {
    final t       = context.poppyTheme;
    final entries = context.read<EntriesProvider>().entries;
    final fp = context.read<ThemeProvider>().currentFontPairData;

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
              style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
          const Spacer(),
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
              style: AppTextStyles.bodySmallSans(t.textSecondary, fp)
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
                    color: t.accent.withValues(alpha: 0.3),
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
                        style: AppTextStyles.labelLargeSans(t.accent, fp)
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
      AppSnackbar.success(context, 'Your account has been deleted.');
    } else {
      AppSnackbar.error(
        context,
        auth.errorMessage ?? 'Could not delete account. Please try again.',
      );
    }
  }
}

// ─── Sub-widgets ───

class _ProfileChip extends StatelessWidget {
  final String email;
  const _ProfileChip({required this.email});

  @override
  Widget build(BuildContext context) {
    final t       = context.poppyTheme;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'P';
    final fp = context.read<ThemeProvider>().currentFontPairData;

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
                  Text(email,
                      style:
                      AppTextStyles.bodySmallSans(t.textPrimary, fp),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Signed in',
                      style: AppTextStyles.labelLargeSans(
                          t.textTertiary, fp)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final t  = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
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
                  style: AppTextStyles.titleSmallSans(t.textPrimary, fp)),
              Text(desc,
                  style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg,
        AppSpacing.lg, AppSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary, fp)
            .copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
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
    final fp = context.read<ThemeProvider>().currentFontPairData;

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
                      style: AppTextStyles.titleSmallSans(color, fp)),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(value!,
                        style: AppTextStyles.labelLargeSans(
                            t.textTertiary, fp)),
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

class _RowLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
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
    final t  = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        'Are you absolutely sure?',
        style: AppTextStyles.headlineSmall(t.textPrimary, fp),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type DELETE in capitals to confirm.',
            style: AppTextStyles.bodySmallSans(t.textSecondary, fp),
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
              style: AppTextStyles.bodyMedium(t.textPrimary, fp),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle:
                AppTextStyles.bodyMedium(t.textTertiary, fp),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical:   AppSpacing.sm,
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
            t.accent.withValues(alpha: 0.3),
          ),
          child: const Text('Delete my account'),
        ),
      ],
    );
  }
}
