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

  const EntryCard({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t   = context.poppyTheme;
    final now = DateTime.now();
    return InkWell(
      onTap: onTap,
      splashColor:    t.accentLight,
      highlightColor: t.accentLight.withOpacity(0.5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Color accent strip ──────────────────────
            Container(
              width: AppStroke.colorStrip,
              color: entry.colorTag.color as Color,
            ),

            // ── Date column ─────────────────────────────
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(
                vertical:   AppSpacing.md,
                horizontal: AppSpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.entryDate.day.toString(),
                    style: AppTextStyles.entryDayNumber(t.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM').format(entry.entryDate).toUpperCase(),
                    style: AppTextStyles.entryMonthAbbr(t.textTertiary),
                  ),
                ],
              ),
            ),

            // ── Divider ─────────────────────────────────
            VerticalDivider(
              width: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border,
            ),

            // ── Title + preview ──────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical:   AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      style: AppTextStyles.entryTitle(
                        entry.title.isEmpty ? t.textTertiary : t.textPrimary,
                      ),
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

            // ── Word count + chevron ─────────────────────
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Column(
                mainAxisAlignment:  MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(AppIcons.chevronRight,
                      size: AppIconSize.xs, color: t.textTertiary),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.wordCount}w',
                    style: AppTextStyles.wordCount(t.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}