import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/entry_card.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Home Screen
//  Location: lib/screens/home/home_screen.dart
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _selectedIds = {};

  bool get _isBatchMode => _selectedIds.isNotEmpty;
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EntriesProvider>().fetchEntries();
    });
  }

  void _onEntryTap(Entry entry) {
    if (_isBatchMode) {
      _toggleSelect(entry.id);
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.write,
      arguments: entry.id,
    );
  }

  void _onEntryLongPress(Entry entry) {
    setState(() => _selectedIds.add(entry.id));
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _cancelBatch() => setState(() => _selectedIds.clear());

  Future<void> _deleteBatch() async {
    final t = context.poppyTheme;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'entry' : 'entries'}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final provider = context.read<EntriesProvider>();
    for (final id in _selectedIds.toList()) {
      await provider.deleteEntry(id);
    }
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final entries = context.watch<EntriesProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: _isBatchMode ? _buildBatchAppBar(t) : _buildNormalAppBar(t),
      body: _buildBody(context, t, entries),
      floatingActionButton: _isBatchMode
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.write),
              tooltip: 'New entry',
              child: const Icon(AppIcons.add, size: AppIconSize.sm),
            ),
    );
  }

  AppBar _buildNormalAppBar(PoppyThemeExtension t) {
    return AppBar(
      backgroundColor: t.surface,
      title: Row(
        children: [
          const PoppyLogo(size: 30, prominent: false),
          const SizedBox(width: AppSpacing.sm),
          Text(kAppName, style: AppTextStyles.appBarTitle(t.textPrimary)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(AppIcons.search,
              color: t.textSecondary, size: AppIconSize.sm),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
          tooltip: 'Search',
        ),
        IconButton(
          icon: Icon(AppIcons.settings,
              color: t.textSecondary, size: AppIconSize.sm),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          tooltip: 'Settings',
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  AppBar _buildBatchAppBar(PoppyThemeExtension t) {
    return AppBar(
      actionsPadding: const EdgeInsets.all(AppSpacing.sm),
      toolbarHeight: AppSpacing.xxxl,
      elevation: 0,
      backgroundColor: t.background,
      leading: IconButton(
        icon:
            Icon(AppIcons.close, color: t.textSecondary, size: AppIconSize.sm),
        onPressed: _cancelBatch,
      ),
      title: Text('${_selectedIds.length} selected',
          style: AppTextStyles.appBarTitle(t.textPrimary)),
      actions: [
        IconButton(
          onPressed: () {
            final provider = context.read<EntriesProvider>();
            setState(() {
              _selectedIds
                ..clear()
                ..addAll(provider.entries.map((e) => e.id));
            });
          },
          icon: Icon(AppIcons.selectAll, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          icon: Icon(AppIcons.delete, color: t.accent, size: AppIconSize.sm),
          onPressed: _selectedIds.isEmpty ? null : _deleteBatch,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context,
      PoppyThemeExtension t,
      EntriesProvider entries,
      ) {
    if (entries.isLoading) {
      return ListView.separated(
        itemCount: 8,
        separatorBuilder: (_, __) => Divider(
          height: AppStroke.hairline,
          thickness: AppStroke.hairline,
          color: t.border,
        ),
        itemBuilder: (_, __) => _SkeletonCard(),
      );
    }

    if (entries.status == EntriesStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.offline,
                size: AppIconSize.xl, color: t.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load entries.',
              style: AppTextStyles.emptySubtitle(t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => entries.fetchEntries(),
              child: Text('Try again', style: AppTextStyles.link(t.accent)),
            ),
          ],
        ),
      );
    }

    if (entries.entries.isEmpty) return _EmptyState();

    final grouped = _groupByYear(entries.entries);

    List<Entry> visibleEntries;

    if (_selectedYear == null) {
      visibleEntries = entries.entries; // ALL entries
    } else {
      final selectedSection = grouped.firstWhere(
            (section) => section['year'] == _selectedYear,
      );
      visibleEntries = selectedSection['entries'] as List<Entry>;
    }

    return Column(
      children: [
        // ─────────────────────────────────────────
        // YEAR TABS (horizontal)
        // ─────────────────────────────────────────
        SizedBox(
          height: AppSpacing.xxl,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            scrollDirection: Axis.horizontal,
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final year = grouped[index]['year'] as String;
              final isSelected = _selectedYear == year;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedYear == year) {
                      _selectedYear = null; // toggle OFF → ALL
                    } else {
                      _selectedYear = year; // filter
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? t.accentLight : t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: t.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    year,
                    style: AppTextStyles.sectionLabel(
                      isSelected ? t.accent : t.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ─────────────────────────────────────────
        // ENTRIES LIST (filtered or all)
        // ─────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: visibleEntries.length,
            separatorBuilder: (_, __) => Divider(
              height: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border,
              indent: AppSpacing.lg + AppStroke.colorStrip,
            ),
            itemBuilder: (context, i) {
              final entry = visibleEntries[i];
              final isSelected = _selectedIds.contains(entry.id);

              return Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: Container(color: t.accentLight),
                    ),
                  EntryCard(
                    entry: entry,
                    onTap: () => _onEntryTap(entry),
                    onLongPress: () => _onEntryLongPress(entry),
                    isBatchMode: _isBatchMode,
                    isSelected: isSelected,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  List<Map<String, dynamic>> _groupByYear(List<Entry> entries) {
    final Map<String, List<Entry>> map = {};
    for (final e in entries) {
      final label = DateFormat('yyyy').format(e.entryDate);
      map.putIfAbsent(label, () => []).add(e);
    }
    return map.entries
        .map((e) => {'year': e.key, 'entries': e.value})
        .toList();
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PoppyLogo(size: AppIconSize.logo, prominent: false),
          const SizedBox(height: AppSpacing.lg),
          Text('Your diary is empty.',
              style: AppTextStyles.emptyTitle(t.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap + to write your first entry.',
              style: AppTextStyles.emptySubtitle(t.textTertiary)),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return SizedBox(
      height: AppComponentSize.entryCardHeight,
      child: Row(
        children: [
          Container(width: AppStroke.colorStrip, color: t.border),
          Container(width: 48, color: t.surface),
          VerticalDivider(
              width: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border),
          Expanded(
            child: Container(
              color: t.surface,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: t.border.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
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
