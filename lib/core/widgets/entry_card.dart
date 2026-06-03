import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Card Widget
//  Location: lib/core/widgets/entry_card.dart
// ─────────────────────────────────────────────────────────────

class EntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isBatchMode;
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
    final t  = context.poppyTheme;
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
            // Color strip
            Container(
              width: AppStroke.colorStrip,
              color: entry.colorTag.color as Color,
            ),

            // Date column (safer)
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
                        style: AppTextStyles.calendarDay(monthColor,fp),
                      ),
                      Text(
                        DateFormat('MMM')
                            .format(entry.entryDate)
                            .toUpperCase(),
                        style: AppTextStyles.labelSmall(monthColor,fp),
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

            // Title + preview (FIXED)
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
                          entry.title.isEmpty
                              ? t.textTertiary
                              : t.textPrimary,
                          fp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (entry.contentPreview.isNotEmpty) ...[
                      const SizedBox(height: 2),
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

            // Word count / checkbox (safe width)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: isBatchMode
                      ? AnimatedContainer(
                    duration: AppDuration.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? t.accent
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? t.accent
                            : t.border,
                        width: AppStroke.thin,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                      AppIcons.check,
                      size: 12,
                      color: AppColors.white,
                    )
                        : null,
                  )
                      : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${entry.wordCount}w',
                      style: AppTextStyles.labelSmall(
                          t.textTertiary,fp),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}