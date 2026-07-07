import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/auth/presentation/providers/auth_provider.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/journal/presentation/providers/entries_provider.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:poppy/features/settings/data/services/export_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Settings Screen
// ─────────────────────────────────────────────────────────────

class _ExportResult {
  final String? savedPath;
  const _ExportResult({this.savedPath});
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final td = themeProvider.currentThemeData;
    final fp = themeProvider.currentFontPairData;

    return Scaffold(
      backgroundColor: td.background,
      appBar: AppBar(
        backgroundColor: td.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: AppIconSize.xs, color: td.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings', style: AppTextStyles.titleLarge(td.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          _ProfileChip(email: auth.user?.email ?? ''),
          const SizedBox(height: AppSpacing.lg),

          const _SectionLabel('Personalisation'),
          _Card(children: [
            _SettingsRow(
              icon: AppIcons.appearance,
              label: 'Appearance',
              value: 'Fonts · Colors',
              onTap: () => _push(context, AppRoutes.appearance),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.tagOutline,
              label: 'Entry Tags',
              value: 'Names · Colors',
              onTap: () => _push(context, AppRoutes.tags),
            ),
          ]),

          const _SectionLabel('Account & Security'),
          _Card(children: [
            _SettingsRow(
              icon: AppIcons.person,
              label: 'Account',
              value: 'Name · Email · Password',
              onTap: () => _push(context, AppRoutes.account),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.security,
              label: 'Security',
              value: 'PIN lock · Biometrics',
              onTap: () => _push(context, AppRoutes.security),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.emailUnread,
              label: 'Notifications',
              value: 'Writing reminders',
              onTap: () => _push(context, AppRoutes.notifications),
            ),
          ]),

          const _SectionLabel('Data'),
          _Card(children: [
            _SettingsRow(
              icon: AppIcons.export,
              label: 'Export diary',
              value: 'Download a backup',
              onTap: () => _onExport(context),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.import,
              label: 'Import diary',
              value: 'Restore from a file',
              onTap: () => _onImport(context),
            ),
          ]),

          const _SectionLabel('Support'),
          _Card(children: [
            _SettingsRow(
              icon: AppIcons.info,
              label: 'Send feedback',
              value: 'Bugs · Ideas · Questions',
              onTap: () => _onFeedback(context),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.checkCircle,
              label: 'About Poppy',
              value: 'Version · Licenses',
              onTap: () => _push(context, AppRoutes.about),
            ),
          ]),

          const _SectionLabel('Legal'),
          _Card(children: [
            _SettingsRow(
              icon: AppIcons.privacyPolicy,
              label: 'Privacy Policy',
              onTap: () => _push(context, AppRoutes.legalPrivacy),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.Tos,
              label: 'Terms of Use',
              onTap: () => _push(context, AppRoutes.legalTerms),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.Osl,
              label: 'Open Source Licenses',
              onTap: () => _push(context, AppRoutes.legalOpensource),
            ),
          ]),

          const _SectionLabel('Account actions'),
          _Card(children: [
            _SettingsRow(
              icon: AppIcons.logout,
              label: 'Sign out',
              isDestructive: true,
              onTap: () => _onSignOut(context),
            ),
            _RowLine(),
            _SettingsRow(
              icon: AppIcons.delete,
              label: 'Delete account',
              value: 'Removes all data permanently',
              isDestructive: true,
              onTap: () => _onDeleteAccount(context),
            ),
          ]),
        ],
      ),
    );
  }

  void _push(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);

  Future<void> _onExport(BuildContext context) async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      PoppySnackbar.warning(context, 'No entries to export.');
      return;
    }

    final result = await PoppyDialog.show<_ExportResult>(
      context,
      builder: () => _ExportChoiceDialog(entries: entries),
    );

    if (result == null || !context.mounted) return;

    final svc = ExportService();
    if (result.savedPath != null) {
      final filename = result.savedPath!.split('/').last;
      PoppySnackbar.success(
        context,
        'Saved to Downloads/$filename',
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => svc.shareExportFile(result.savedPath!),
        ),
      );
    } else {
      PoppySnackbar.info(context, 'Export ready to share.');
    }
  }

  Future<void> _onImport(BuildContext context) async {
    final svc = ExportService();

    late ImportPreview preview;
    try {
      preview = await svc.previewImport();
    } on ImportCancelledException {
      return;
    } catch (e) {
      if (context.mounted) {
        PoppySnackbar.error(
          context,
          e is FormatException ? e.message : 'Could not read the file.',
        );
      }
      return;
    }

    if (!context.mounted) return;

    final count = await PoppyDialog.show<int>(
      context,
      builder: () => _ImportConfirmDialog(preview: preview),
    );

    if (count == null || !context.mounted) return;

    final entryWord = count == 1 ? 'entry' : 'entries';

    if (count > 0) {
      await context.read<EntriesProvider>().fetchEntries();
      if (context.mounted) {
        PoppySnackbar.success(context, '$count $entryWord imported.');
      }
    } else {
      PoppySnackbar.info(context, 'No new entries found.');
    }
  }

  Future<void> _onFeedback(BuildContext context) async {
    const email = 'support@sarahelbahloul.dev';
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    await PoppyDialog.showInfo(
      context,
      title: 'Send feedback',
      confirmLabel: null,
      message: 'We read every message. Bugs, ideas, or just to say hi — all welcome.',
      body: GestureDetector(
        onTap: () {
          Clipboard.setData(const ClipboardData(text: email));
          Navigator.pop(context);
          PoppySnackbar.success(context, 'Email address copied.');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: t.accentLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: t.accent.withValues(alpha: 0.25), width: AppStroke.hairline),
          ),
          child: Row(
            children: [
              Icon(AppIcons.email, size: AppIconSize.xs, color: t.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(email, style: AppTextStyles.bodySmallSans(t.accent, fp))),
              Icon(AppIcons.copy, size: AppIconSize.xs, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSignOut(BuildContext context) async {
    final confirmed = await PoppyDialog.showConfirm(
      context,
      title: 'Sign out?',
      confirmLabel: 'Sign out',
      message: 'Your diary is safely stored in the cloud. You can sign back in any time.',
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<EntriesProvider>().clear();
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  Future<void> _onDeleteAccount(BuildContext context) async {
    final t = context.poppyTheme;
    final entries = context.read<EntriesProvider>().entries;

    final proceed = await PoppyDialog.show<bool>(
      context,
      builder: () => PoppyDialog.destructive(
        title: 'Delete account',
        titleIcon: AppIcons.warning,
        confirmLabel: 'Continue',
        cancelLabel: null,
        barrierDismissible: true,
        message: 'This permanently deletes your Poppy account and every diary entry you have written. It cannot be undone.',
        body: entries.isNotEmpty
            ? DialogInfoBanner(
          icon: AppIcons.export,
          text: 'You have ${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}. Export a backup before you go.',
        )
            : null,
        extraActions: [
          if (entries.isNotEmpty)
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _onExport(context);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: t.accent,
                  width: AppStroke.thin,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              child: Text('Export first', style: TextStyle(color: t.accent)),
            ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    final confirmed = await PoppyDialog.show<bool>(
      context,
      dismissible: false,
      builder: () => const _DeleteAccountConfirmDialog(),
    );

    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.deleteAccount();
    if (!context.mounted) return;

    if (ok) {
      context.read<EntriesProvider>().clear();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      PoppySnackbar.success(context, 'Your account has been deleted.');
    } else {
      PoppySnackbar.error(context, auth.errorMessage ?? 'Could not delete account.');
    }
  }
}

class _ProfileChip extends StatelessWidget {
  final String email;
  const _ProfileChip({required this.email});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'P';
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.border, width: AppStroke.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.full), color: t.accentLight),
              child: Center(
                child: Text(initial, style: AppTextStyles.titleLarge(t.accent, fp).copyWith(fontSize: 18)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email, style: AppTextStyles.bodySmallSans(t.textPrimary, fp), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Signed in', style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Export choice dialog
// ─────────────────────────────────────────────────────────────

class _ExportChoiceDialog extends StatefulWidget {
  final List<Entry> entries;
  const _ExportChoiceDialog({required this.entries});

  @override
  State<_ExportChoiceDialog> createState() => _ExportChoiceDialogState();
}

class _ExportChoiceDialogState extends State<_ExportChoiceDialog> {
  bool _encrypted = true;
  bool _isExporting = false;
  String? _error;

  Future<void> _onExport(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _error = null;
    });
    try {
      final svc = ExportService();
      final savedPath = await svc.exportEntries(
        widget.entries,
        encrypted: _encrypted,
      );
      if (mounted) {
        Navigator.pop(context, _ExportResult(savedPath: savedPath));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _error = 'Export failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return PoppyDialog(
      title: 'Export diary',
      intent: _encrypted ? PoppyDialogIntent.standard : PoppyDialogIntent.destructive,
      cancelLabel: _isExporting ? null : 'Cancel',
      confirmLabel: 'Export',
      confirmEnabled: !_isExporting,
      confirmContent: _isExporting
          ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: AppSpacing.xxs,
          color: Colors.white,
        ),
      )
          : null,
      onConfirm: _isExporting ? null : _onExport,
      barrierDismissible: !_isExporting,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExportOptionTile(
            icon: AppIcons.lock,
            title: 'Encrypted',
            desc: 'Entries are scrambled. Only importable back into this account.',
            color: context.poppyTheme.accent,
            isSelected: _encrypted,
            onTap: _isExporting ? null : () => setState(() => _encrypted = true),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ExportOptionTile(
            icon: AppIcons.export,
            title: 'Plain text',
            desc: 'Readable by anyone who opens the file.',
            color: AppColors.error,
            isSelected: !_encrypted,
            onTap: _isExporting ? null : () => setState(() => _encrypted = false),
            warning: 'Your diary entries will be unprotected. Only use if needed outside Poppy.',
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.labelSmall(AppColors.error, fp)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Import confirm dialog
// ─────────────────────────────────────────────────────────────

class _ImportConfirmDialog extends StatefulWidget {
  final ImportPreview preview;
  const _ImportConfirmDialog({required this.preview});

  @override
  State<_ImportConfirmDialog> createState() => _ImportConfirmDialogState();
}

class _ImportConfirmDialogState extends State<_ImportConfirmDialog> {
  bool _isImporting = false;
  String? _error;

  Future<void> _onImport(BuildContext context) async {
    setState(() {
      _isImporting = true;
      _error = null;
    });
    try {
      final svc = ExportService();
      final count = await svc.commitImport(widget.preview);
      if (mounted) {
        Navigator.pop(context, count);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _error = e is FormatException ? e.message : 'Import failed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    final preview = widget.preview;
    final entryWord = preview.entryCount == 1 ? 'entry' : 'entries';

    return PoppyDialog(
      title: 'Import entries?',
      message: 'New entries will be added. Existing entries with the same ID will be skipped.',
      cancelLabel: _isImporting ? null : 'Cancel',
      confirmLabel: 'Import $entryWord',
      confirmEnabled: !_isImporting,
      confirmContent: _isImporting
          ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: AppSpacing.xxs,
          color: Colors.white,
        ),
      )
          : null,
      onConfirm: _isImporting ? null : _onImport,
      barrierDismissible: !_isImporting,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: t.accentLight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.accent.withValues(alpha: 0.2), width: AppStroke.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.import, size: AppIconSize.xs, color: t.accent),
                const SizedBox(width: AppSpacing.sm),
                Text('${preview.entryCount} $entryWord found',
                    style: AppTextStyles.titleSmallSans(t.textPrimary, fp)),
              ],
            ),
            if (preview.exportedAt.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text('Exported ${preview.exportedAtFormatted}',
                    style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(preview.isEncrypted ? 'Encrypted backup' : 'Plain text backup',
                  style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppTextStyles.labelSmall(AppColors.error, fp)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? warning;

  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.isSelected,
    this.onTap,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? color : t.border,
            width: isSelected ? AppStroke.medium : AppStroke.hairline,
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: AppIconSize.xs, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.titleSmallSans(t.textPrimary, fp)),
                        Text(desc, style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: AppIconSize.sm,
                    height: AppIconSize.sm,
                    child: isSelected ? Icon(AppIcons.checkCircle, size: AppIconSize.sm, color: color) : null,
                  ),
                ],
              ),
              if (isSelected && warning != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.info, size: 13, color: color),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(warning!, style: AppTextStyles.labelSmall(color, fp).copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary, fp).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

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
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isDestructive;
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
    final t = context.poppyTheme;
    final color = isDestructive ? AppColors.error : t.textPrimary;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppComponentSize.settingsIconCol,
              color: isDestructive ? AppColors.error : t.textTertiary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.titleSmallSans(color, fp)),
                  if (value != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(value!, style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
                  ],
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Divider(
      height: AppStroke.hairline,
      thickness: AppStroke.hairline,
      color: t.border,
      indent: AppSpacing.md + AppComponentSize.settingsIconCol + AppSpacing.md,
    );
  }
}

class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() => _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState extends State<_DeleteAccountConfirmDialog> {
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
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return PoppyDialog.destructive(
      title: 'Are you absolutely sure?',
      confirmLabel: 'Delete my account',
      confirmEnabled: _ctrl.text == 'DELETE',
      barrierDismissible: false,
      message: 'Type DELETE in capitals to confirm.',
      body: Container(
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.border, width: AppStroke.hairline),
        ),
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: AppTextStyles.bodyMedium(t.textPrimary, fp),
          decoration: InputDecoration(
            hintText: 'DELETE',
            hintStyle: AppTextStyles.bodyMedium(t.textTertiary, fp),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
        ),
      ),
    );
  }
}