import 'package:flutter/material.dart';
import 'package:flutter_bidi_text/bidi_text_field.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/core/widgets/widgets.dart';
import 'package:poppy/screens/home/settings_drawer.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Home Screen
//  Location: lib/screens/home/home_screen.dart
// ─────────────────────────────────────────────────────────────

/// The main dashboard of the application.
///
/// This screen displays a reverse-chronological list of journal entries.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  // Getters for cleaner access to providers and frequently used data
  EntriesProvider get _entriesProvider => context.read<EntriesProvider>();

  ThemeProvider get _themeProvider => context.read<ThemeProvider>();

  FontPairData get _fp => _themeProvider.currentFontPairData;

  AuthProvider get _authProvider => context.read<AuthProvider>();

  String? _selectedYear;
  TagColorData? _selectedColor;

  bool get _isBatchMode => _selectedIds.isNotEmpty;
  bool _searching = false;
  final FocusNode _searchFocusNode = FocusNode();

  bool _sortDesc = false;
  bool _fetchedOnce = false;
  String _greeting = '';
  DateTime? _lastBackPress;

  // ─────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _authProvider.addListener(_onAuthChanged);

    final hour = DateTime.now().hour;
    _greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAuthChanged();
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_authProvider.encryptionReady) {
      if (!_fetchedOnce) {
        _fetchedOnce = true;
        _entriesProvider.fetchEntries();
      }
    } else {
      _fetchedOnce = false;
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  Filtering & Search
  // ─────────────────────────────────────────────────────────────

  void _applyAllFilters() {
    DateTime? fromDate;
    DateTime? toDate;

    if (_selectedYear != null) {
      final year = int.parse(_selectedYear!);
      fromDate = DateTime(year);
      toDate = DateTime(year + 1);
    }

    _entriesProvider.setFilters(
      query: _searchController.text.isNotEmpty ? _searchController.text : null,
      fromDate: fromDate,
      toDate: toDate,
      colorTag: _selectedColor?.dbValue,
    );
  }

  void _startSearch() {
    setState(() => _searching = true);
    Future.delayed(AppDuration.instant, () {
      _searchFocusNode.requestFocus();
    });
  }

  void _exitSearch() {
    setState(() {
      _searching = false;
      _searchController.clear();
    });
    _entriesProvider.clearFilters();
    _applyAllFilters();
    _searchFocusNode.unfocus();
  }

  // ─────────────────────────────────────────────────────────────
  //  Navigation & Selection
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  //  Batch Actions
  // ─────────────────────────────────────────────────────────────

  Future<void> _openColorPicker() async {
    TagColorData? tempSelected;

    final selected = await PoppyDialog.show<TagColorData>(
      context,
      builder: () => StatefulBuilder(
        builder: (context, setDialogState) {
          return PoppyDialog(
            title: 'Set color tag',
            confirmLabel: 'Apply',
            cancelLabel: 'Cancel',
            confirmEnabled: tempSelected != null,
            onConfirm: (ctx) => Navigator.pop(ctx, tempSelected),
            body: Center(
              child: ColorTagSelector(
                selected: tempSelected,
                layout: ColorTagSelectorLayout.wrap,
                showLabelOnSelect: true,
                onSelected: (colorData) {
                  setDialogState(() => tempSelected = colorData);
                },
              ),
            ),
          );
        },
      ),
    );

    if (selected != null) {
      await _changeColorBatch(selected);
    }
  }

  Future<void> _deleteBatch() async {
    final count = _selectedIds.length;
    final confirmed = await PoppyDialog.showDestructive(
      context,
      title: 'Delete $count ${count == 1 ? 'entry' : 'entries'}?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirmed != true) return;

    await _entriesProvider.deleteEntries(_selectedIds.toList());
    setState(() => _selectedIds.clear());
  }

  Future<void> _changeColorBatch(TagColorData color) async {
    final toUpdate = _selectedIds
        .map((id) => _entriesProvider.getById(id))
        .whereType<Entry>()
        .map((e) => e.copyWith(colorTag: color))
        .toList();

    if (toUpdate.isNotEmpty) {
      await _entriesProvider.updateEntries(toUpdate);
    }
    setState(() => _selectedIds.clear());
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch providers here to trigger rebuilds on data changes
    context.watch<EntriesProvider>();
    context.watch<ThemeProvider>();
    context.watch<AuthProvider>();

    final t = context.poppyTheme;
    final entries = _entriesProvider.filteredEntries;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        if (_isBatchMode) {
          _cancelBatch();
          return;
        }
        if (_searching) {
          _exitSearch();
          return;
        }
        if (_lastBackPress == null ||
            DateTime.now().difference(_lastBackPress!) >
                const Duration(seconds: 2)) {
          _lastBackPress = DateTime.now();
          PoppySnackbar.info(context, 'Press back again to exit');
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: t.background,
        drawer: const SettingsDrawer(),
        appBar: _isBatchMode ? _batchAppBar(t) : _normalAppBar(t),
        body: RefreshIndicator(
          onRefresh: () async => await _entriesProvider.fetchEntries(),
          child: _body(t, entries),
        ),
        floatingActionButton: _isBatchMode
            ? null
            : FloatingActionButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.write),
                tooltip: 'New entry',
                child: const Icon(AppIcons.add, size: AppIconSize.sm),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  AppBar Variants
  // ─────────────────────────────────────────────────────────────

  AppBar _normalAppBar(PoppyThemeExtension t) {
    final username = _authProvider.displayName.split(' ')[0];

    return AppBar(
      actionsPadding: const EdgeInsets.all(AppSpacing.sm),
      toolbarHeight: AppComponentSize.appBarHeight,
      elevation: 0,
      titleSpacing: 0,
      backgroundColor: t.background,
      title: _searching
          ? null
          : Text(
              '$_greeting, $username!',
              style: AppTextStyles.titleLarge(t.textPrimary, _fp),
            ),
      leading: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Builder(
          builder: (context) => IconButton(
            icon: Icon(AppIcons.sandwich,
                color: t.textSecondary, size: AppIconSize.sm),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      actions: [
        _searching
            ? SizedBox(
                key: const ValueKey('searchField'),
                width: AppComponentSize.searchFieldWidth(context),
                height: AppComponentSize.filterBarHeight,
                child: BidiTextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: AppTextStyles.bodyMedium(t.textPrimary, _fp),
                    textAlignVertical: TextAlignVertical.center,
                    textAlign: TextAlign.start,
                    onChanged: (_) => _applyAllFilters(),
                    decoration: InputDecoration(
                      fillColor: t.surface,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 0,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide(color: t.accent, width: AppStroke.thin),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide:
                            BorderSide(color: t.accent, width: AppStroke.thin),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide:
                            BorderSide(color: t.border, width: AppStroke.thin),
                      ),
                      hintText: 'Search entries...',
                      hintStyle:
                          AppTextStyles.labelLargeSerif(t.textTertiary, _fp),
                      suffixIcon: GestureDetector(
                        onTap: _exitSearch,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Icon(AppIcons.close,
                              size: AppIconSize.xs, color: t.textSecondary),
                        ),
                      ),
                    )),
              )
            : IconButton(
                key: const ValueKey('searchIcon'),
                icon: Icon(AppIcons.search,
                    color: t.textSecondary, size: AppIconSize.sm),
                onPressed: _startSearch,
              ),
        IconButton(
          tooltip: _sortDesc
              ? 'Newest first'
              : 'Oldest first',
          icon: Icon(
            _sortDesc
                ? AppIcons.sortAsc
                : AppIcons.sortDesc,
            color: _sortDesc ? t.accent: t.textSecondary,
            size: AppIconSize.sm,
          ),
          onPressed: () => setState(() => _sortDesc = !_sortDesc),
        ),
      ],
    );
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
          style: AppTextStyles.titleLarge(t.textPrimary, _fp)),
      actions: [
        IconButton(
          tooltip: 'Select All',
          onPressed: () {
            setState(() {
              _selectedIds
                ..clear()
                ..addAll(_entriesProvider.filteredEntries.map((e) => e.id));
            });
          },
          icon:
              Icon(AppIcons.checkCircle, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          tooltip: 'Set Color Tag',
          onPressed: _selectedIds.isEmpty ? null : _openColorPicker,
          icon: Icon(AppIcons.color, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          icon: const Icon(AppIcons.delete,
              color: AppColors.error, size: AppIconSize.sm),
          onPressed: _selectedIds.isEmpty ? null : _deleteBatch,
          tooltip: 'Delete Selected Entries',
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Body Sections
  // ─────────────────────────────────────────────────────────────

  Widget _body(PoppyThemeExtension t, List<Entry> entries) {
    if (_entriesProvider.isLoading && !_fetchedOnce) {
      return Column(
        children: [
          const _FiltersSkeleton(),
          const SizedBox(height: AppSpacing.md),
          Divider(
              height: AppStroke.hairline,
              thickness: AppStroke.hairline,
              color: t.border),
          Expanded(
            child: ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, __) => Divider(
                  height: AppStroke.hairline,
                  thickness: AppStroke.hairline,
                  color: t.border),
              itemBuilder: (_, __) => _SkeletonCard(),
            ),
          ),
        ],
      );
    }
    if (_entriesProvider.status == EntriesStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.offline, size: AppIconSize.xl, color: t.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load entries.',
                style: AppTextStyles.bodySmallSans(t.textSecondary, _fp)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => _entriesProvider.fetchEntries(),
              child: Text('Try again',
                  style: AppTextStyles.bodySmallSans(t.accent, _fp)),
            ),
          ],
        ),
      );
    }

    if (_entriesProvider.entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.heightOf(context) / 4),
          _EmptyState(),
        ],
      );
    }

    final years = _extractYears(_entriesProvider.entries);
    final displayedEntries = _sortDesc ? entries.reversed.toList() : entries;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Year Filter Dropdown
            Flexible(
              child: Container(
                height: AppComponentSize.filterBarHeight,
                width: AppComponentSize.searchFieldWidth(context),
                margin: const EdgeInsets.only(
                    left: AppSpacing.md, right: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: _selectedYear != null ? t.accent : t.border,
                      width: AppStroke.thin),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.calendar,
                        size: AppIconSize.sm,
                        color:
                            _selectedYear != null ? t.accent : t.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MenuAnchor(
                        alignmentOffset:
                            const Offset(-AppSpacing.sm, AppSpacing.xs),
                        style: MenuStyle(
                          minimumSize: WidgetStatePropertyAll(Size(
                              AppComponentSize.searchFieldWidth(context) / 2.7,
                              50)),
                          maximumSize: WidgetStatePropertyAll(Size(
                              AppComponentSize.searchFieldWidth(context) / 2,
                              300)),
                          backgroundColor: WidgetStatePropertyAll(t.surface),
                          shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(AppRadius.sm),
                                bottomRight: Radius.circular(AppRadius.sm)),
                          )),
                        ),
                        menuChildren: years.map((year) {
                          final isSelected = year == _selectedYear;
                          return MenuItemButton(
                            style: ButtonStyle(
                              alignment: AlignmentDirectional.centerStart,
                              minimumSize: WidgetStatePropertyAll(Size(
                                  AppComponentSize.searchFieldWidth(context) /
                                      2.7,
                                  AppComponentSize.filterBarHeight / 2)),
                            ),
                            onPressed: () {
                              setState(() => _selectedYear = year);
                              _applyAllFilters();
                            },
                            child: Text(year,
                                style: AppTextStyles.labelLargeSans(
                                    isSelected
                                        ? t.textPrimary
                                        : t.textSecondary,
                                    _fp)),
                          );
                        }).toList(),
                        builder: (context, controller, child) => InkWell(
                          onTap: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: child,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedYear ??
                                    '${years.last} - ${years.first}',
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelLargeSans(
                                    _selectedYear != null
                                        ? t.textPrimary
                                        : t.textSecondary,
                                    _fp),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(AppIcons.chevronDown,
                                size: AppIconSize.sm, color: t.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedYear != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedYear = null);
                          _applyAllFilters();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: Icon(AppIcons.close,
                              size: AppIconSize.xs, color: t.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Color Tag Filter
            Flexible(
              child: Container(
                height: AppComponentSize.filterBarHeight,
                width: AppComponentSize.searchFieldWidth(context),
                margin: const EdgeInsets.only(right: AppSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: _selectedColor != null
                          ? _selectedColor!.color
                          : t.border,
                      width: AppStroke.thin),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.color,
                        size: AppIconSize.sm,
                        color: _selectedColor != null
                            ? _selectedColor!.color
                            : t.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: ColorTagSelector(
                        selected: _selectedColor,
                        allowDeselect: true,
                        onSelected: (color) {
                          setState(() => _selectedColor = color);
                          _applyAllFilters();
                        },
                      ),
                    ),
                    if (_selectedColor != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedColor = null);
                          _applyAllFilters();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Icon(AppIcons.close,
                              size: AppIconSize.xs, color: t.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Divider(
            height: AppStroke.hairline,
            thickness: AppStroke.hairline,
            color: t.border),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: displayedEntries.length,
            separatorBuilder: (_, __) => Divider(
                height: AppStroke.hairline,
                thickness: AppStroke.hairline,
                color: t.border),
            itemBuilder: (context, i) {
              final entry = displayedEntries[i];
              final isSelected = _selectedIds.contains(entry.id);
              return Column(
                children: [
                  Stack(
                    children: [
                      if (isSelected)
                        Positioned.fill(child: Container(color: t.accentLight)),
                      EntryCard(
                        entry: entry,
                        onTap: () => _onEntryTap(entry),
                        onLongPress: () => _onEntryLongPress(entry),
                        isBatchMode: _isBatchMode,
                        isSelected: isSelected,
                      ),
                    ],
                  ),
                  if (i == displayedEntries.length - 1) ...[
                    Divider(
                        height: AppStroke.hairline,
                        thickness: AppStroke.hairline,
                        color: t.border)
                  ]
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<String> _extractYears(List<Entry> entries) {
    final years = entries
        .map((e) => DateFormat('yyyy').format(e.entryDate))
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }
}

// ─────────────────────────────────────────────────────────────
//  Private Widgets & Skeletons
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PoppyLogo(size: AppIconSize.logo),
          const SizedBox(height: AppSpacing.lg),
          Text('Your diary is empty.',
              style: AppTextStyles.bodyLarge(t.textPrimary, fp)),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap + to write your first entry.',
              style: AppTextStyles.bodySmallSans(t.textTertiary, fp)),
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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                          color: t.border,
                          borderRadius: BorderRadius.circular(AppRadius.xs))),
                  const SizedBox(height: 6),
                  Container(
                      height: 10,
                      width: 90,
                      decoration: BoxDecoration(
                          color: t.border.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.xs))),
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
          Flexible(child: _SkeletonFilterItem(t: t)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: _SkeletonFilterItem(t: t, isColor: true)),
        ],
      ),
    );
  }
}

class _SkeletonFilterItem extends StatelessWidget {
  final PoppyThemeExtension t;
  final bool isColor;

  const _SkeletonFilterItem({required this.t, this.isColor = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppComponentSize.filterBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border, width: AppStroke.thin)),
      child: Row(
        children: [
          Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  color: t.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: AppSpacing.sm),
          if (!isColor)
            Container(
                height: 10,
                width: 80,
                decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(AppRadius.xs))),
          if (isColor) Expanded(child: Container()),
          if (!isColor) const Spacer(),
          if (!isColor)
            Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: t.border, borderRadius: BorderRadius.circular(3))),
        ],
      ),
    );
  }
}
