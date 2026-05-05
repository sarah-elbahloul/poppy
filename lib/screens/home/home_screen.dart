import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/entry_card.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Home Screen
//  Location: lib/screens/home/home_screen.dart
//
//  Shows the full entry list, newest first.
//  Cards are compact and touch each other.
//  FAB opens the write screen for a new entry.
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch entries once when the screen first mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EntriesProvider>().fetchEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final entries = context.watch<EntriesProvider>();

    return Scaffold(
      backgroundColor: t.background,

      // ── App bar ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: t.background,
        title: Row(
          children: [
            PoppyLogo(size: 26, prominent: false),
            const SizedBox(width: kSpaceSM),
            Text(
              kAppName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: t.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Search
          IconButton(
            icon: Icon(Icons.search, color: t.textSecondary, size: 22),
            onPressed: () => context.push('/search'),
            tooltip: 'Search',
          ),
          // Settings
          IconButton(
            icon: Icon(Icons.tune_outlined, color: t.textSecondary, size: 22),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
          const SizedBox(width: kSpaceXS),
        ],
      ),

      // ── Body ─────────────────────────────────────────────
      body: _buildBody(context, t, entries),

      // ── FAB ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/write'),
        tooltip: 'New entry',
        child: const Icon(Icons.edit_outlined, size: 22),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      PoppyThemeExtension t,
      EntriesProvider entries,
      ) {
    // Loading state
    if (entries.isLoading) {
      return ListView.separated(
        itemCount: 8,
        separatorBuilder: (_, __) =>
            Divider(height: 0.5, thickness: 0.5, color: t.border),
        itemBuilder: (_, __) => _SkeletonCard(),
      );
    }

    // Error state
    if (entries.status == EntriesStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 36, color: t.textTertiary),
            const SizedBox(height: kSpaceMD),
            Text(
              'Could not load entries.',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: kSpaceSM),
            TextButton(
              onPressed: () => entries.fetchEntries(),
              child: Text(
                'Try again',
                style: TextStyle(color: t.accent),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (entries.entries.isEmpty) {
      return _EmptyState();
    }

    // ── Entry list ────────────────────────────────────────
    // Group entries by month so the list has clear sections.
    final grouped = _groupByMonth(entries.entries
        .map((e) => e)
        .toList());

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: grouped.length,
      itemBuilder: (context, sectionIndex) {
        final section = grouped[sectionIndex];
        final monthLabel = section['month'] as String;
        final sectionEntries = section['entries'] as List;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.only(
                left: kSpaceLG,
                top: kSpaceLG,
                bottom: kSpaceXS,
              ),
              child: Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: t.textTertiary,
                  letterSpacing: 0.6,
                ),
              ),
            ),

            // Cards for this month — separated by a hairline divider
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: t.border, width: 0.5),
                  bottom: BorderSide(color: t.border, width: 0.5),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sectionEntries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: t.border,
                  indent: kSpaceLG + kColorStripWidth,
                ),
                itemBuilder: (context, i) {
                  final entry = sectionEntries[i];
                  return EntryCard(
                    entry: entry,
                    onTap: () => context.push('/entry/${entry.id}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Group entries by "MMMM yyyy" label ────────────────────

  List<Map<String, dynamic>> _groupByMonth(List entries) {
    final Map<String, List> map = {};

    for (final entry in entries) {
      final label = DateFormat('MMMM yyyy').format(entry.createdAt);
      map.putIfAbsent(label, () => []).add(entry);
    }

    return map.entries
        .map((e) => {'month': e.key, 'entries': e.value})
        .toList();
  }
}

// ── Empty state ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PoppyLogo(size: 52, prominent: false),
          const SizedBox(height: kSpaceLG),
          Text(
            'Your diary is empty.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: kSpaceXS),
          Text(
            'Tap + to write your first entry.',
            style: TextStyle(fontSize: 13, color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading card ──────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return SizedBox(
      height: 58,
      child: Row(
        children: [
          // Color strip placeholder
          Container(width: kColorStripWidth, color: t.border),
          // Date placeholder
          Container(
            width: 48,
            color: t.surface,
          ),
          VerticalDivider(width: 1, thickness: 0.5, color: t.border),
          // Text placeholder
          Expanded(
            child: Container(
              color: t.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: kSpaceMD,
                vertical: kSpaceMD,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: t.border.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}