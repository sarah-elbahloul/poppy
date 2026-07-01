import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
// See the same note in dialogs.dart: this reaches into ThemeProvider
// (a feature-level class) purely to render snackbar text in the user's
// chosen font. Swap or stub this out if reusing the file elsewhere.

/// A centralized snackbar system for the Poppy app.
///
/// Provides a consistent, branded, and premium appearance for
/// notifications across the application.
class PoppySnackbar {
  PoppySnackbar._();

  /// Shows a success snackbar with an optional [title] and [action].
  static void success(
      BuildContext context,
      String message, {
        String? title,
        Duration? duration,
        SnackBarAction? action,
      }) {
    _show(
      context,
      message,
      title: title,
      duration: duration,
      action: action,
      type: _SnackbarType.success,
    );
  }

  /// Shows an error snackbar for failures and critical alerts.
  static void error(
      BuildContext context,
      String message, {
        String? title,
        Duration? duration,
        SnackBarAction? action,
      }) {
    _show(
      context,
      message,
      title: title,
      duration: duration,
      action: action,
      type: _SnackbarType.error,
    );
  }

  /// Shows a warning snackbar for non-critical alerts or precautions.
  static void warning(
      BuildContext context,
      String message, {
        String? title,
        Duration? duration,
        SnackBarAction? action,
      }) {
    _show(
      context,
      message,
      title: title,
      duration: duration,
      action: action,
      type: _SnackbarType.warning,
    );
  }

  /// Shows an informational snackbar.
  static void info(
      BuildContext context,
      String message, {
        String? title,
        Duration? duration,
        SnackBarAction? action,
      }) {
    _show(
      context,
      message,
      title: title,
      duration: duration,
      action: action,
      type: _SnackbarType.info,
    );
  }

  static void _show(
      BuildContext context,
      String message, {
        String? title,
        Duration? duration,
        SnackBarAction? action,
        required _SnackbarType type,
      }) {
    // Haptics
    switch (type) {
      case _SnackbarType.success:
        HapticFeedback.lightImpact();
        break;
      case _SnackbarType.warning:
        HapticFeedback.mediumImpact();
        break;
      case _SnackbarType.error:
        HapticFeedback.heavyImpact();
        break;
      case _SnackbarType.info:
        HapticFeedback.selectionClick();
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    late final Color iconColor;
    late final Color backgroundColor;
    late final Color borderColor;

    late final IconData icon;

    switch (type) {
      case _SnackbarType.success:
        iconColor = AppColors.success;
        backgroundColor = AppColors.successLight;
        borderColor = AppColors.successMuted;
        icon = AppIcons.checkCircle;
        break;

      case _SnackbarType.error:
        iconColor = AppColors.error;
        backgroundColor = AppColors.errorLight;
        borderColor = AppColors.errorMuted;
        icon = AppIcons.warning;
        break;

      case _SnackbarType.warning:
        iconColor = AppColors.warning;
        backgroundColor = AppColors.warningLight;
        borderColor = AppColors.warningMuted;
        icon = AppIcons.warning;
        break;

      case _SnackbarType.info:
        iconColor = t.accent;
        backgroundColor = t.surface;
        borderColor = t.border;
        icon = AppIcons.info;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        content: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor, width: AppStroke.hairline),
            boxShadow: AppShadows.sheet,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Accent strip
                Container(
                  width: AppStroke.colorStrip,
                  color: iconColor,
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: title != null
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: AppIconSize.md,
                          color: iconColor,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null) ...[
                                Text(
                                  title,
                                  style: AppTextStyles.titleSmallSans(
                                    t.textPrimary,
                                    fp,
                                  ).copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                              ],
                              Text(
                                message,
                                style: AppTextStyles.bodySmallSans(
                                  t.textSecondary,
                                  fp,
                                ).copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              action.onPressed();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: iconColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              action.label,
                              style: AppTextStyles.labelLargeSans(
                                iconColor,
                                fp,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SnackbarType { success, error, warning, info }