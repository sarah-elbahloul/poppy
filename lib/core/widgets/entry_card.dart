import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/services/local_db_service.dart';
import 'package:provider/provider.dart';

/// A card widget that displays a summary of a journal [Entry].
///
/// Features:
/// - A color strip indicating the entry's category/mood.
/// - A date column showing the day and month.
/// - Title and content preview text.
/// - A sync status indicator (dot) appearing when there are pending changes.
/// - Supports batch selection mode with a circular checkbox.
class EntryCard extends StatelessWidget {
  /// The entry data to display.
  final Entry entry;

  /// Callback triggered when the card is tapped.
  final VoidCallback onTap;

  /// Optional callback triggered when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Whether the card is currently in batch selection mode.
  final bool isBatchMode;

  /// Whether this specific entry is selected in batch mode.
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
        highlightColor: t.accentLight.withOpacity(0.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color strip indicating the entry's category/mood.
            Container(
              width: AppStroke.colorStrip,
              color: entry.colorTag.color as Color,
            ),

            // Date indicator column.
            Flexible(
              flex: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 50),
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: monthColor.withOpacity(0.08),
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

            // Main content area: Title and Preview.
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

            // Metadata column: Word count or Selection checkbox.
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

/// Displays the word count and an optional status dot for synchronization state.
class _WordCountWithStatus extends StatelessWidget {
  final Entry entry;
  final PoppyThemeExtension t;
  final FontPairData fp;

  const _WordCountWithStatus({
    required this.entry,
    required this.t,
    required this.fp,
  });

  /// Returns the color of the sync status dot.
  ///
  /// Returns null if the entry is fully synchronized.
  Color? _dotColor() {
    switch (entry.syncStatus) {
      case SyncStatus.pendingCreate:
        // Red indicates a brand new entry that has never been synced.
        return AppColors.error;
      case SyncStatus.pendingUpdate:
        // Amber indicates local edits are awaiting synchronization.
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
        // Sync status dot - animates in when local changes are detected.
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
                        shape: BoxShape.circle,
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

/// A circular checkbox displayed during batch selection mode.
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
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? accent : Colors.transparent,
        border: Border.all(
          color: isSelected ? accent : border,
          width: AppStroke.thin,
        ),
      ),
      child: isSelected
          ? const Icon(AppIcons.check, size: 12, color: AppColors.white)
          : null,
    );
  }
}
