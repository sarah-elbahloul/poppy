import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/models/entry.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Card Widget
//  Location: lib/core/widgets/entry_card.dart
//
//  Compact entry row used on the home screen.
//  Layout: [color strip] [date column] [title + preview]
//  Cards touch each other — no gap between them.
//  Only a subtle divider separates rows.
// ─────────────────────────────────────────────────────────────

class EntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final now = DateTime.now();
    final isToday = _isSameDay(entry.createdAt, now);
    final isYesterday = _isSameDay(
      entry.createdAt,
      now.subtract(const Duration(days: 1)),
    );

    return InkWell(
      onTap: onTap,
      splashColor: t.accentLight,
      highlightColor: t.accentLight.withOpacity(0.5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Color accent strip ──────────────────────────
            Container(
              width: kColorStripWidth,
              color: entry.colorTag.color,
            ),

            // ── Date column ─────────────────────────────────
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(
                vertical: kSpaceMD,
                horizontal: kSpaceSM,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayNumber(entry.createdAt),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _monthAbbr(entry.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: t.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider between date and text ───────────────
            VerticalDivider(
              width: 1,
              thickness: 0.5,
              color: t.border,
            ),

            // ── Title + content preview ──────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceMD,
                  vertical: kSpaceMD,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Day label (Today / Yesterday / weekday)
                    if (isToday || isYesterday) ...[
                      Text(
                        isToday ? 'Today' : 'Yesterday',
                        style: TextStyle(
                          fontSize: 10,
                          color: t.accent,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Title
                    Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: entry.title.isEmpty
                            ? t.textTertiary
                            : t.textPrimary,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Content preview — only if there is content
                    if (entry.contentPreview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.contentPreview,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.textTertiary,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Word count + chevron ─────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: kSpaceMD),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: t.textTertiary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.wordCount}w',
                    style: TextStyle(
                      fontSize: 10,
                      color: t.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date helpers ───────────────────────────────────────────

  String _dayNumber(DateTime dt) => dt.day.toString();

  String _monthAbbr(DateTime dt) =>
      DateFormat('MMM').format(dt).toUpperCase();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}