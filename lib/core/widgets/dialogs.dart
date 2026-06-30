import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:provider/provider.dart';

import '../../features/settings/presentation/providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Shared Dialogs
//  Location: lib/core/widgets/dialogs.dart
// ─────────────────────────────────────────────────────────────

/// Visual/semantic intent of a [PoppyDialog]'s primary action.
enum PoppyDialogIntent {
  standard,
  destructive,
  info,
}

/// A single, consistent dialog shape used for every confirmation in Poppy.
///
/// Reorganized for better UX/UI and ease of use.
/// Supports standard patterns for confirmation, destructive actions, and informational alerts.
class PoppyDialog extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final String? message;
  final Widget? body;
  final String? cancelLabel;
  final String? confirmLabel;
  final bool confirmEnabled;
  final PoppyDialogIntent intent;
  final List<Widget> extraActions;
  final void Function(BuildContext context)? onConfirm;
  final bool barrierDismissible;
  final bool showPrimaryAction;

  const PoppyDialog({
    super.key,
    required this.title,
    this.titleIcon,
    this.message,
    this.body,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.showPrimaryAction = true,
    this.confirmEnabled = true,
    this.intent = PoppyDialogIntent.standard,
    this.extraActions = const [],
    this.onConfirm,
    this.barrierDismissible = true,
  });

  const PoppyDialog.confirm({
    super.key,
    required this.title,
    this.titleIcon,
    this.message,
    this.body,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.showPrimaryAction = true,
    this.confirmEnabled = true,
    this.extraActions = const [],
    this.onConfirm,
    this.barrierDismissible = true,
  }) : intent = PoppyDialogIntent.standard;

  const PoppyDialog.destructive({
    super.key,
    required this.title,
    this.titleIcon,
    this.message,
    this.body,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.showPrimaryAction = true,
    this.confirmEnabled = true,
    this.extraActions = const [],
    this.onConfirm,
    this.barrierDismissible = true,
  }) : intent = PoppyDialogIntent.destructive;

  const PoppyDialog.info({
    super.key,
    required this.title,
    this.titleIcon,
    this.message,
    this.body,
    this.confirmLabel = 'Done',
    this.showPrimaryAction = true,
    this.onConfirm,
    this.barrierDismissible = true,
  })  : intent = PoppyDialogIntent.info,
        cancelLabel = '',
        confirmEnabled = true,
        extraActions = const [];

  // ─────────────────────────────────────────────────────────────
  //  Static Helpers
  // ─────────────────────────────────────────────────────────────

  /// Shows a standard confirmation dialog.
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    String? message,
    Widget? body,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData? icon,
    bool dismissible = true,
  }) =>
      show<bool>(context,
          builder: () => PoppyDialog.confirm(
                title: title,
                message: message,
                body: body,
                confirmLabel: confirmLabel,
                cancelLabel: cancelLabel,
                titleIcon: icon,
                barrierDismissible: dismissible,
              ));

  /// Shows a destructive confirmation dialog (e.g. for deletion).
  static Future<bool?> showDestructive(
    BuildContext context, {
    required String title,
    String? message,
    Widget? body,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    IconData? icon,
    bool dismissible = true,
  }) =>
      show<bool>(context,
          builder: () => PoppyDialog.destructive(
                title: title,
                message: message,
                body: body,
                confirmLabel: confirmLabel,
                cancelLabel: cancelLabel,
                titleIcon: icon,
                barrierDismissible: dismissible,
              ));

  /// Shows an informational dialog with a single button.
  static Future<bool?> showInfo(
    BuildContext context, {
    required String title,
    String? message,
    Widget? body,
    String? confirmLabel = 'Done',
    IconData? icon,
    bool dismissible = true,
  }) =>
      show<bool>(context,
          builder: () => PoppyDialog.info(
                title: title,
                message: message,
                body: body,
                confirmLabel: confirmLabel,
                titleIcon: icon,
                barrierDismissible: dismissible,
              ));

  /// Internal base show method.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function() builder,
    bool? dismissible,
  }) {
    final widget = builder();
    final resolvedDismissible = dismissible ??
        (widget is PoppyDialog ? widget.barrierDismissible : true);
    return showDialog<T>(
      context: context,
      barrierDismissible: resolvedDismissible,
      builder: (_) => widget,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────

  Color _confirmColor(PoppyThemeExtension t) {
    switch (intent) {
      case PoppyDialogIntent.destructive:
        return AppColors.error;
      case PoppyDialogIntent.standard:
      case PoppyDialogIntent.info:
        return t.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    final confirmColor = _confirmColor(t);
    final isInfo = intent == PoppyDialogIntent.info;
    final isCentered = titleIcon != null;

    return AlertDialog(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titlePadding: const EdgeInsets.all(AppSpacing.lg),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titleIcon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Icon(titleIcon, color: confirmColor, size: AppIconSize.md),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            title,
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
            style: AppTextStyles.headlineSmall(t.textPrimary, fp),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (message != null)
              Text(
                message!,
                textAlign: isCentered ? TextAlign.center : TextAlign.start,
                style: AppTextStyles.bodySmallSans(t.textSecondary, fp)
                    .copyWith(height: 1.6),
              ),
            if (message != null && body != null)
              const SizedBox(height: AppSpacing.md),
            if (body != null) body!,
          ],
        ),
      ),
      actions: [
        if (!isInfo && cancelLabel != null) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelLabel!, style: TextStyle(color: t.textTertiary)),
          )
        ],
        if (!isInfo) ...extraActions,
        if (showPrimaryAction && confirmLabel != null) ...[
          FilledButton(
            onPressed: !confirmEnabled
                ? null
                : () =>
                (onConfirm ?? (ctx) => Navigator.pop(ctx, true))(context),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: confirmColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            child: Text(confirmLabel!),
          ),
        ]
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper Widgets
// ─────────────────────────────────────────────────────────────

/// The small icon + tinted-box note used beneath a dialog's main body text.
class DialogInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final DialogBannerTone tone;

  const DialogInfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.tone = DialogBannerTone.info,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    final Color fg;
    final Color bg;
    final Color border;
    switch (tone) {
      case DialogBannerTone.info:
        fg = t.accent;
        bg = t.accentLight;
        border = t.accent.withValues(alpha: 0.2);
        break;
      case DialogBannerTone.warning:
        fg = AppColors.warning;
        bg = AppColors.warningLight;
        border = AppColors.warningMuted;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border, width: AppStroke.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: AppIconSize.xs, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.labelLargeSans(fg, fp).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

enum DialogBannerTone { info, warning }

/// Standard body text styling for plain-text dialog content.
class DialogBodyText extends StatelessWidget {
  final String text;

  const DialogBodyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return Text(
      text,
      style: AppTextStyles.bodySmallSans(t.textSecondary, fp)
          .copyWith(height: 1.6),
    );
  }
}
