import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/models/entry.dart';

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
    final t = context.poppyTheme;
    final monthColor = MonthColors.of(entry.entryDate.month);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: t.accentLight,
      highlightColor: t.accentLight.withOpacity(0.5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color strip
            Container(
              width: AppStroke.colorStrip,
              color: entry.colorTag.color as Color,
            ),
            // Date column
            Container(
              width: AppSpacing.xxl,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: monthColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.entryDate.day.toString(),
                    style: AppTextStyles.entryDayNumber(monthColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM').format(entry.entryDate).toUpperCase(),
                    style: AppTextStyles.entryMonthAbbr(monthColor),                  ),
                ],
              ),
            ),
            VerticalDivider(
              width: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border,
            ),
            // Title + preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      style: AppTextStyles.entryTitle(entry.title.isEmpty ? t.textTertiary : t.textPrimary,),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.contentPreview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.contentPreview,
                        style: AppTextStyles.entryPreview(t.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Word count
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: isBatchMode
                    ? AnimatedContainer(
                        duration: AppDuration.fast,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? t.accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? t.accent : t.border,
                            width: AppStroke.thin,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(AppIcons.check,
                                size: 12, color: AppColors.white)
                            : null,
                      )
                    : Text(
                      '${entry.wordCount}w',
                      style: AppTextStyles.wordCount(t.textTertiary),
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
