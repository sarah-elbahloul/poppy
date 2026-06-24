import 'package:flutter/material.dart';
import 'package:flutter_bidi_text/bidi_text_field.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/screens/home/settings_drawer.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Home Screen
//  Location: lib/screens/home/home_screen.dart
// ─────────────────────────────────────────────────────────────

/// The main entry point of the application once the user is authenticated.
/// Displays a list of journal entries with search, filter, and batch
/// operation capabilities.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  String? _selectedYear;
  TagColorData? _selectedColor;

  bool get _isBatchMode => _selectedIds.isNotEmpty;
  bool _searching = false;
  final FocusNode _searchFocusNode = FocusNode();

  bool _sortDesc = false;

  bool _fetchedOnce = false;
  String _greeting = '';

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    _greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    // Listen to AuthProvider for encryptionReady changes rather than using
    // context.watch inside didChangeDependencies, which can cause
    // "looking up a deactivated widget" errors and misses re-login cycles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      auth.addListener(_onAuthChanged);
      // Trigger immediately if encryption is already ready (e.g. hot restart).
      _onAuthChanged();
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.encryptionReady) {
      if (!_fetchedOnce) {
        _fetchedOnce = true;
        context.read<EntriesProvider>().fetchEntries();
      }
    } else {
      // Encryption is no longer ready (signed out / key cleared) — reset so
      // the next sign-in triggers a fresh fetch.
      _fetchedOnce = false;
    }
  }

  @override
  void dispose() {
    // Safe: removeListener is a no-op if auth was disposed first.
    final auth = context.read<AuthProvider>();
    auth.removeListener(_onAuthChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── Filter Logic ───

  /// Aggregates all active filters (search, year, color) and applies
  /// them to the [EntriesProvider].
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
    Future.delayed(AppDuration.instant, () {
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
    _applyAllFilters();
    _searchFocusNode.unfocus();
  }

  // ─── Entry Actions ───

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

  /// Opens a color picker to apply a color tag to all selected entries.
  Future<void> _openColorPicker() async {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;
    final selected = await showModalBottomSheet<TagColorData>(
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
                style: AppTextStyles.labelLargeSans(t.textPrimary, fp),
              ),
              const SizedBox(height: AppSpacing.md),
              ColorTagSelector(
                selected: null,
                layout: ColorTagSelectorLayout.wrap,
                showLabelOnSelect: false,
                onSelected: (colorData) {
                  if (colorData != null) Navigator.pop(context, colorData);
                },
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

  /// Deletes all currently selected entries after confirmation.
  Future<void> _deleteBatch() async {
    final t = context.poppyTheme;
    final count = _selectedIds.length;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Delete $count ${count == 1 ? 'entry' : 'entries'}?',
          style: AppTextStyles.labelLargeSans(t.textPrimary, fp),
        ),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.bodyLarge(t.textPrimary, fp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLargeSans(t.textPrimary, fp),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTextStyles.labelLargeSans(AppColors.error, fp),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = context.read<EntriesProvider>();
    await provider.deleteEntries(_selectedIds.toList());
    setState(() => _selectedIds.clear());
  }

  Future<void> _changeColorBatch(TagColorData color) async {
    final provider = context.read<EntriesProvider>();
    final toUpdate = _selectedIds
        .map((id) => provider.getById(id))
        .whereType<Entry>()
        .map((e) => e.copyWith(colorTag: color))
        .toList();

    if (toUpdate.isNotEmpty) {
      await provider.updateEntries(toUpdate);
    }
    setState(() => _selectedIds.clear());
  }

  // ─── Helpers ───

  List<String> _extractYears(List<Entry> entries) {
    final years = entries
        .map((e) => DateFormat('yyyy').format(e.entryDate))
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final provider = context.watch<EntriesProvider>();
    final entries = provider.filteredEntries;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. Close drawer if open
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2. Exit batch mode
        if (_isBatchMode) {
          _cancelBatch();
          return;
        }

        // 3. Exit search mode (optional)
        if (_searching) {
          _exitSearch();
          return;
        }

        // 4. Double-back to exit
        final now = DateTime.now();

        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;

          AppSnackbar.info(
            context,
            'Press back again to exit',
          );

          return;
        }

        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: t.background,
        drawer: const SettingsDrawer(),
        appBar: _isBatchMode ? _batchAppBar(t) : _normalAppBar(t, provider),
        body: RefreshIndicator(
            onRefresh: () async {
              await provider.fetchEntries();
            },
            child: _body(context, t, provider, entries)
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

  AppBar _normalAppBar(PoppyThemeExtension t, EntriesProvider provider) {
    final fp = context.read<ThemeProvider>().currentFontPairData;
    final username = context.read<AuthProvider>().displayName.split(' ')[0];

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
          style: AppTextStyles.titleLarge(t.textPrimary, fp),
        ),
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
              style: AppTextStyles.bodyMedium(t.textPrimary, fp),
              textAlignVertical: TextAlignVertical.center,
              textAlign: TextAlign.start,
              onChanged: (_) => _applyAllFilters(),
              decoration: InputDecoration(
                fillColor: t.surface,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: t.accent,
                    width: AppStroke.thin,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: t.accent,
                    width: AppStroke.thin,
                  ),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: t.border,
                      width: AppStroke.thin,
                    )),
                hintText: 'Search entries...',
                hintStyle:
                AppTextStyles.labelLargeSerif(t.textTertiary, fp),
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
          IconButton(
            icon: Icon(AppIcons.sort, color: t.textSecondary, size: AppIconSize.sm),
            tooltip: 'Sort ${_sortDesc ? 'descending' : 'ascending'}',
            onPressed: () => setState(() => _sortDesc = !_sortDesc),
          ),
        ]);
  }

  AppBar _batchAppBar(PoppyThemeExtension t) {
    final fp = context.read<ThemeProvider>().currentFontPairData;

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
          style: AppTextStyles.titleLarge(t.textPrimary, fp)),
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
          icon: Icon(AppIcons.checkCircle, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          tooltip: 'Set Color Tag',
          onPressed: _selectedIds.isEmpty ? null : _openColorPicker,
          icon: Icon(AppIcons.color, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          icon: const Icon(AppIcons.delete, color: AppColors.error, size: AppIconSize.sm),
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
    final fp = context.read<ThemeProvider>().currentFontPairData;

    if (provider.isLoading && !_fetchedOnce) {
      return Column(
        children: [
          const _FiltersSkeleton(),
          const SizedBox(height: AppSpacing.md),
          Divider(
            height: AppStroke.hairline,
            thickness: AppStroke.hairline,
            color: t.border,
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, __) => Divider(
                height: AppStroke.hairline,
                thickness: AppStroke.hairline,
                color: t.border,
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
              style: AppTextStyles.bodySmallSans(t.textSecondary, fp),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => provider.fetchEntries(),
              child: Text('Try again',
                  style: AppTextStyles.bodySmallSans(t.accent, fp)),
            ),
          ],
        ),
      );
    }

    if (provider.entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.heightOf(context) / 4),
          _EmptyState(),
        ],
      );
    }

    final years = _extractYears(provider.entries);
    final displayedEntries = _sortDesc ? entries.reversed.toList() : entries;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                height: AppComponentSize.filterBarHeight,
                width: AppComponentSize.searchFieldWidth(context),
                margin: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.sm,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _selectedYear != null ? t.accent : t.border,
                    width: AppStroke.thin,
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
                                      topLeft: Radius.circular(0),
                                      topRight: Radius.circular(0),
                                      bottomLeft: Radius.circular(AppRadius.sm),
                                      bottomRight:
                                      Radius.circular(AppRadius.sm)))),
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
                            child: Text(
                              year,
                              style: AppTextStyles.labelLargeSans(
                                isSelected ? t.textPrimary : t.textSecondary,
                                fp,
                              ),
                            ),
                          );
                        }).toList(),
                        builder: (context, controller, child) {
                          return InkWell(
                            onTap: () {
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open();
                            },
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: child,
                          );
                        },
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
                                  fp,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              AppIcons.chevronDown,
                              size: AppIconSize.sm,
                              color: t.textSecondary,
                            ),
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
                width: AppComponentSize.searchFieldWidth(context),
                margin: const EdgeInsets.only(right: AppSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _selectedColor != null
                        ? _selectedColor!.color
                        : t.border,
                    width: AppStroke.thin,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.color,
                      size: AppIconSize.sm,
                      color: _selectedColor != null
                          ? _selectedColor!.color
                          : t.textSecondary,
                    ),
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
        const SizedBox(height: AppSpacing.md),
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

              return Column(
                children: [
                  Stack(
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
                  ),
                  if (i == displayedEntries.length - 1) ...[
                    Divider(
                      height: AppStroke.hairline,
                      thickness: AppStroke.hairline,
                      color: t.border,
                    )
                  ]
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
    final fp = context.read<ThemeProvider>().currentFontPairData;

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
                      color: t.border.withValues(alpha: 0.6),
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
          Flexible(
            child: Container(
              height: AppComponentSize.filterBarHeight,
              width: AppComponentSize.searchFieldWidth(context),
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: t.border,
                  width: AppStroke.thin,
                ),
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
          Flexible(
            child: Container(
              height: AppComponentSize.filterBarHeight,
              width: AppComponentSize.searchFieldWidth(context),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: t.border,
                  width: AppStroke.thin,
                ),
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
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: EntryTags.all.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm * 1.5),
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