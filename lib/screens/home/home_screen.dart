import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/entry_card.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/color_dot.dart';
import '../settings/settings_drawer.dart';

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

  final TextEditingController _searchController = TextEditingController();

  String? _selectedYear;
  EntryColorData? _selectedColor;

  bool get _isBatchMode => _selectedIds.isNotEmpty;
  bool _searching = false;
  final FocusNode _searchFocusNode = FocusNode();

  bool _sortDesc = false;

  bool _fetchedOnce = false;

  @override
  void initState() {
    super.initState();
    // fetch is deferred to didChangeDependencies so we can gate on
    // encryptionReady — the key must be in memory before we decrypt.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final encReady = context.watch<AuthProvider>().encryptionReady;
    if (!_fetchedOnce && encReady) {
      _fetchedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<EntriesProvider>().fetchEntries();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UNIFIED FILTER LOGIC
  // ─────────────────────────────────────────────

  void _applyAllFilters() {
    final provider = context.read<EntriesProvider>();

    DateTime? fromDate;
    DateTime? toDate;

    if (_selectedYear != null) {
      final year = int.parse(_selectedYear!);
      fromDate = DateTime(year);
      toDate = DateTime(year + 1);
    }

    provider.setFilters(
      query: _searchController.text.isNotEmpty ? _searchController.text : null,
      fromDate: fromDate,
      toDate: toDate,
      colorTag: _selectedColor?.dbValue,
    );
  }

  void _startSearch() {
    setState(() => _searching = true);

    Future.delayed(Duration(milliseconds: 50), () {
      _searchFocusNode.requestFocus();
    });
  }

  void _exitSearch() {
    final provider = context.read<EntriesProvider>();
    setState(() {
      _searching = false;
      _searchController.clear();
    });
    provider.clearFilters();
    _applyAllFilters(); // clears query but keeps year/color filters
    _searchFocusNode.unfocus();
  }

  // ─────────────────────────────────────────────
  // ENTRY ACTIONS
  // ─────────────────────────────────────────────

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

  Future<void> _openColorPicker() async {
    final t = context.poppyTheme;

    final selected = await showModalBottomSheet<EntryColorData>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose color',
                style: AppTextStyles.labelLargeSans(t.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: EntryColors.all.map((colorData) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, colorData),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (colorData.color as Color),
                          width: AppStroke.medium,
                        ),
                      ),
                      child: ColorDot(
                        colorData: colorData,
                        size: 28,
                        isSelected: false,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await _changeColorBatch(selected);
    }
  }

  Future<void> _deleteBatch() async {
    final t = context.poppyTheme;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadius.lg),
          ),
        ),
        title: Text(
          'Delete $count ${count == 1 ? 'entry' : 'entries'}?',
          style: AppTextStyles.labelLargeSans(t.textPrimary),
        ),
        content: Text('This cannot be undone.',
          style: AppTextStyles.bodyLarge(t.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLargeSans(t.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTextStyles.labelLargeSans(AppColors.error),
            ),
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

  Future<void> _changeColorBatch(EntryColorData color) async {
    final provider = context.read<EntriesProvider>();

    for (final id in _selectedIds.toList()) {
      final entry = provider.getById(id);
      if (entry == null) continue;

      await provider.updateEntry(
        entry.copyWith(colorTag: color),
      );
    }

    setState(() => _selectedIds.clear());
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  List<String> _extractYears(List<Entry> entries) {
    final years = entries
        .map((e) => DateFormat('yyyy').format(e.entryDate))
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final provider = context.watch<EntriesProvider>();
    final entries = provider.filteredEntries;

    return Scaffold(
      backgroundColor: t.background,
      drawer: const SettingsDrawer(),
      appBar: _isBatchMode ? _batchAppBar(t) : _normalAppBar(t, provider),
      body: _body(context, t, provider, entries),
      floatingActionButton: _isBatchMode
          ? null
          : FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.write),
        tooltip: 'New entry',
        child: const Icon(AppIcons.add, size: AppIconSize.sm),
      ),
    );
  }

  AppBar _normalAppBar(PoppyThemeExtension t, EntriesProvider provider) {
    return AppBar(
        actionsPadding: const EdgeInsets.all(AppSpacing.sm),
        toolbarHeight: AppComponentSize.appBarHeight,
        elevation: 0,
        titleSpacing: 0,
        backgroundColor: t.background,
        title: Text(kAppName, style: AppTextStyles.titleLarge(t.textPrimary)),
        leading: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Builder(
            builder: (context) => IconButton(
              icon: Icon(
                AppIcons.sandwich,
                color: t.textSecondary,
                size: AppIconSize.sm,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),        actions: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _searching
            ? SizedBox(
          key: const ValueKey('searchField'),
          width: AppComponentSize.searchFieldWidth,
          height: AppComponentSize.filterBarHeight,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: AppTextStyles.bodyMedium(t.textPrimary),
            textAlignVertical: TextAlignVertical.center,
            onChanged: (_) => _applyAllFilters(),
            decoration: InputDecoration(
              fillColor: t.surface,
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: _selectedColor != null
                        ? (_selectedColor!.color as Color)
                        : t.border,
                    width: AppStroke.medium,
                  )
              ),
              hintText: 'Search entries...',
              hintStyle: AppTextStyles.labelLargeSerif(t.textTertiary),
              suffixIcon: GestureDetector(
                onTap: _exitSearch,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(
                    AppIcons.close,
                    size: AppIconSize.xs,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        )
            : IconButton(
          key: const ValueKey('searchIcon'),
          icon: Icon(AppIcons.search,
              color: t.textSecondary, size: AppIconSize.sm),
          onPressed: _startSearch,
        ),
      ),
      IconButton(
        icon: Icon(AppIcons.sort, color: t.textSecondary, size: AppIconSize.sm),
        tooltip: 'Sort ${_sortDesc ?  'descending': 'ascending'}',
        onPressed: ()=> setState(() => _sortDesc = !_sortDesc),
      ),
    ]);
  }

  AppBar _batchAppBar(PoppyThemeExtension t) {
    return AppBar(
      actionsPadding: const EdgeInsets.all(AppSpacing.sm),
      toolbarHeight: AppComponentSize.appBarHeight,
      elevation: 0,
      titleSpacing: 0,
      backgroundColor: t.background,
      leading: IconButton(
        icon:
        Icon(AppIcons.close, color: t.textSecondary, size: AppIconSize.sm),
        onPressed: _cancelBatch,
      ),
      title: Text('${_selectedIds.length} selected',
          style: AppTextStyles.titleLarge(t.textPrimary)),
      actions: [
        IconButton(
          tooltip: 'Select All',
          onPressed: () {
            final provider = context.read<EntriesProvider>();
            setState(() {
              _selectedIds
                ..clear()
                ..addAll(provider.filteredEntries.map((e) => e.id));
            });
          },
          icon: Icon(AppIcons.selectAll, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          tooltip: 'Set Color Tag',
          onPressed: _selectedIds.isEmpty ? null : _openColorPicker,
          icon: Icon(AppIcons.color, color: t.accent, size: AppIconSize.sm),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton(
          icon: Icon(AppIcons.delete, color: t.accent, size: AppIconSize.sm),
          onPressed: _selectedIds.isEmpty ? null : _deleteBatch,
          tooltip: 'Delete Selected Entries',
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _body(
      BuildContext context,
      PoppyThemeExtension t,
      EntriesProvider provider,
      List<Entry> entries,
      ) {
    if (provider.isLoading || !_fetchedOnce) {
      return Column(
        children: [
          // ─────────────────────────────────────────
          // FILTER TABS SKELETON
          // ─────────────────────────────────────────
          const _FiltersSkeleton(),

          const SizedBox(height: AppSpacing.sm),

          // ─────────────────────────────────────────
          // ENTRIES LIST SKELETON
          // ─────────────────────────────────────────

          Divider(
            height: AppStroke.hairline,
            thickness: AppStroke.hairline,
            color: t.border,
            indent: AppSpacing.lg + AppStroke.colorStrip,
          ),

          Expanded(
            child: ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, __) => Divider(
                height: AppStroke.hairline,
                thickness: AppStroke.hairline,
                color: t.border,
                indent: AppSpacing.lg + AppStroke.colorStrip,
              ),
              itemBuilder: (_, __) => _SkeletonCard(),
            ),
          ),
        ],
      );
    }
    if (provider.status == EntriesStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.offline, size: AppIconSize.xl, color: t.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load entries.',
              style: AppTextStyles.bodySmallSans(t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => provider.fetchEntries(),
              child: Text('Try again', style: AppTextStyles.bodySmallSans(t.accent)),
            ),
          ],
        ),
      );
    }

    if (provider.entries.isEmpty) return _EmptyState();

    final years = _extractYears(provider.entries);
    final displayedEntries = _sortDesc
        ? entries.reversed.toList()
        : entries;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                height: AppComponentSize.filterBarHeight,
                width: AppComponentSize.searchFieldWidth,
                margin: const EdgeInsets.only(
                    left: AppSpacing.md, right: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _selectedYear != null ? t.accent : t.border,
                    width: AppStroke.medium,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: AppIconSize.sm,
                      color: _selectedYear != null ? t.accent : t.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    /// Expanded dropdown
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: t.surface,
                          menuMaxHeight: 400,
                          menuWidth: AppComponentSize.searchFieldWidth/2,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          style: AppTextStyles.labelLargeSans(
                            _selectedYear != null
                                ? t.textPrimary
                                : t.textSecondary,
                          ),
                          icon: Icon(
                            AppIcons.chevronDown,
                            size: AppIconSize.sm,
                            color: t.textSecondary,
                          ),
                          hint: Text(
                            '${years.last} - ${years.first}',
                            style: AppTextStyles.labelLargeSans(t.textSecondary),
                          ),
                          value: _selectedYear,
                          items: years
                              .map((y) => DropdownMenuItem(value: y, child: Text(y)),)
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedYear = value);
                            _applyAllFilters();
                          },
                        ),
                      ),
                    ),

                    /// Clear button (nice UX touch)
                    if (_selectedYear != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedYear = null);
                          _applyAllFilters();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: Icon(
                            AppIcons.close,
                            size: AppIconSize.xs,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: Container(
                height: AppComponentSize.filterBarHeight,
                width: AppComponentSize.searchFieldWidth,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _selectedColor != null
                        ? (_selectedColor!.color as Color)
                        : t.border,
                    width: AppStroke.medium,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.color,
                      size: AppIconSize.sm,
                      color: _selectedColor != null
                          ? (_selectedColor!.color as Color)
                          : t.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),

                    /// Scrollable color chips INSIDE container
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: EntryColors.all.map((colorData) {
                          final isSelected = _selectedColor?.id == colorData.id;
                          return GestureDetector(
                            onTap: () {
                              final newColor = isSelected ? null : colorData;

                              setState(() => _selectedColor = newColor);
                              _applyAllFilters();
                            },
                            child: AnimatedContainer(
                              duration: AppDuration.fast,
                              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs/2, vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (colorData.color as Color)
                                    .withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius:
                                BorderRadius.circular(AppRadius.full),
                                border: Border.all(
                                  color: isSelected
                                      ? colorData.color as Color
                                      : Colors.transparent,
                                  width: AppStroke.thin,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ColorDot(
                                    colorData: colorData,
                                    size: AppComponentSize.colorDotChip,
                                    isSelected: false,
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      colorData.name,
                                      style: AppTextStyles.labelLargeSans(
                                        colorData.color as Color,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    /// Clear button
                    if (_selectedColor != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedColor = null);
                          _applyAllFilters();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Icon(
                            AppIcons.close,
                            size: AppIconSize.xs,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ─────────────────────────────────────────
        // ENTRIES LIST (filtered or all)
        // ─────────────────────────────────────────
        Divider(
          height: AppStroke.hairline,
          thickness: AppStroke.hairline,
          color: t.border,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: displayedEntries.length,
            separatorBuilder: (_, __) => Divider(
              height: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border,
            ),
            itemBuilder: (context, i) {
              final entry = displayedEntries[i];
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
              style: AppTextStyles.bodyLarge(t.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap + to write your first entry.',
              style: AppTextStyles.bodySmallSans(t.textTertiary)),
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
          Container(
              width: AppComponentSize.entryDateColWidth, color: t.surface),
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

class _FiltersSkeleton extends StatelessWidget {
  const _FiltersSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // ─────────────────────────────
          // YEAR DROPDOWN SKELETON
          // ─────────────────────────────
          Expanded(
            child: Container(
              height: AppComponentSize.filterBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // fake dropdown text
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),

                  const Spacer(),

                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // ─────────────────────────────
          // COLOR FILTER SKELETON
          // ─────────────────────────────
          Expanded(
            child: Container(
              height: AppComponentSize.filterBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // fake chips row
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: EntryColors.all.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm*1.5),
                      itemBuilder: (_, __) {
                        return Container(
                          width: AppComponentSize.colorDotChip,
                          height: AppComponentSize.colorDotChip,
                          decoration: BoxDecoration(
                            color: t.border,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
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