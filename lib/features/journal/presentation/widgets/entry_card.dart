import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Card Widget
// ─────────────────────────────────────────────────────────────

/// A card widget that displays a summary of a journal [entry].
///
/// Features a color strip for the entry's tag, the date, title,
/// and a preview of the content. It also shows the word count
/// and synchronization status.
class EntryCard extends StatelessWidget {
  /// The journal entry to display.
  final Entry entry;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  /// Optional callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Whether the card is in batch selection mode.
  final bool isBatchMode;

  /// Whether the card is currently selected (used in batch mode).
  final bool isSelected;

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.isBatchMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    final monthColor = MonthColors.of(entry.entryDate.month);

    return SizedBox(
      height: AppComponentSize.entryCardHeight,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: t.accentLight,
        highlightColor: t.accentLight.withValues(alpha: 0.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: AppStroke.colorStrip,
              color: entry.colorTag.color,
            ),

            Flexible(
              flex: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 50),
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: monthColor.withValues(alpha: 0.08),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.entryDate.day.toString(),
                        style: AppTextStyles.calendarDay(monthColor, fp),
                      ),
                      Text(
                        DateFormat('MMM').format(entry.entryDate).toUpperCase(),
                        style: AppTextStyles.labelSmall(monthColor, fp),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            VerticalDivider(
              width: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border,
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        entry.title.isEmpty ? 'Untitled' : entry.title,
                        style: AppTextStyles.titleSmallSerif(
                          entry.title.isEmpty ? t.textTertiary : t.textPrimary,
                          fp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.contentPreview.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          entry.contentPreview,
                          style: AppTextStyles.labelLargeSerif(t.textTertiary, fp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: isBatchMode
                      ? _BatchCheckbox(
                    isSelected: isSelected,
                    accent: t.accent,
                    border: t.border,
                  )
                      : _WordCountWithStatus(
                    entry: entry,
                    t: t,
                    fp: fp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCountWithStatus extends StatelessWidget {
  final Entry entry;
  final PoppyThemeExtension t;
  final FontPairData fp;

  const _WordCountWithStatus({
    required this.entry,
    required this.t,
    required this.fp,
  });

  Color? _dotColor() {
    switch (entry.syncStatus) {
      case SyncStatus.pendingCreate:
        return AppColors.error;
      case SyncStatus.pendingUpdate:
        return AppColors.warning;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${entry.wordCount}w',
            style: AppTextStyles.labelSmall(t.textTertiary, fp),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: dotColor != null
              ? Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Tooltip(
              message: entry.syncStatus == SyncStatus.pendingCreate
                  ? 'Not yet saved to server'
                  : 'Edit not yet synced',
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _BatchCheckbox extends StatelessWidget {
  final bool isSelected;
  final Color accent;
  final Color border;

  const _BatchCheckbox({
    required this.isSelected,
    required this.accent,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.fast,
      width: AppIconSize.sm,
      height: AppIconSize.sm,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: isSelected ? accent : Colors.transparent,
        border: Border.all(
          color: isSelected ? accent : border,
          width: AppStroke.thin,
        ),
      ),
      child: isSelected
          ? const Icon(AppIcons.check, size: AppIconSize.sm * 0.65, color: AppColors.white)
          : null,
    );
  }
}