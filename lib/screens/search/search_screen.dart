import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/color_dot.dart';
import 'package:poppy/core/widgets/entry_card.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Search Screen
//  Location: lib/screens/search/search_screen.dart
//
//  Three ways to find entries:
//    1. Full-text search (title + content)
//    2. Filter by color tag
//    3. Filter by date range
//  Filters compose — you can combine all three.
// ─────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  EntryColorData? _selectedColor;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    context.read<EntriesProvider>().clearSearch();
    super.dispose();
  }

  // ── Run search ────────────────────────────────────────────

  Future<void> _runSearch() async {
    setState(() => _hasSearched = true);
    await context.read<EntriesProvider>().search(
      query: _searchController.text.trim(),
      colorTag: _selectedColor?.dbValue,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  // ── Clear all filters ─────────────────────────────────────

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _selectedColor = null;
      _fromDate = null;
      _toDate = null;
      _hasSearched = false;
    });
    context.read<EntriesProvider>().clearSearch();
  }

  // ── Date picker ───────────────────────────────────────────

  Future<void> _pickDate({required bool isFrom}) async {
    final t = context.poppyTheme;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: t.accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  bool get _hasActiveFilters =>
      _selectedColor != null || _fromDate != null || _toDate != null;

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final provider = context.watch<EntriesProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: t.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Text('Search',
            style: TextStyle(fontSize: 18, color: t.textPrimary)),
        actions: [
          if (_hasActiveFilters || _hasSearched)
            TextButton(
              onPressed: _clearAll,
              child: Text('Clear',
                  style: TextStyle(fontSize: 13, color: t.accent)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLG, kSpaceSM, kSpaceLG, kSpaceXS),
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(kRadiusMD),
                border: Border.all(color: t.border, width: 0.5),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search entries…',
                  hintStyle:
                  TextStyle(fontSize: 15, color: t.textTertiary),
                  prefixIcon: Icon(Icons.search,
                      size: 20, color: t.textTertiary),
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: kSpaceMD),
                ),
                onSubmitted: (_) => _runSearch(),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),

          // ── Color filter row ──────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
              children: EntryColors.all.map((colorData) {
                final isSelected = _selectedColor?.id == colorData.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor =
                      isSelected ? null : colorData;
                    });
                  },
                  child: AnimatedContainer(
                    duration: kAnimFast,
                    margin: const EdgeInsets.only(
                        right: kSpaceSM, top: kSpaceXS, bottom: kSpaceXS),
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpaceSM, vertical: kSpaceXS),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorData.color.withOpacity(0.12)
                          : t.surface,
                      borderRadius: BorderRadius.circular(kRadiusXL),
                      border: Border.all(
                        color: isSelected
                            ? colorData.color
                            : t.border,
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ColorDot(
                          colorData: colorData,
                          size: 10,
                          isSelected: false,
                        ),
                        const SizedBox(width: kSpaceXS),
                        Text(
                          colorData.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? colorData.color
                                : t.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Date range row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLG, kSpaceXS, kSpaceLG, kSpaceSM),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: _fromDate == null
                        ? 'From date'
                        : _formatDate(_fromDate!),
                    isSet: _fromDate != null,
                    onTap: () => _pickDate(isFrom: true),
                    onClear: () => setState(() => _fromDate = null),
                  ),
                ),
                const SizedBox(width: kSpaceSM),
                Expanded(
                  child: _DateChip(
                    label: _toDate == null
                        ? 'To date'
                        : _formatDate(_toDate!),
                    isSet: _toDate != null,
                    onTap: () => _pickDate(isFrom: false),
                    onClear: () => setState(() => _toDate = null),
                  ),
                ),
                const SizedBox(width: kSpaceSM),
                // Search button
                FilledButton(
                  onPressed: _runSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpaceMD, vertical: kSpaceSM),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMD),
                    ),
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text('Search', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),

          Divider(height: 0.5, thickness: 0.5, color: t.border),

          // ── Results ───────────────────────────────────────
          Expanded(
            child: _buildResults(context, t, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
      BuildContext context,
      PoppyThemeExtension t,
      EntriesProvider provider,
      ) {
    if (provider.isSearching) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: t.accent,
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          'Enter a term or pick a filter\nthen tap Search.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: t.textTertiary, height: 1.6),
        ),
      );
    }

    if (provider.searchResults.isEmpty) {
      return Center(
        child: Text(
          'No entries found.',
          style: TextStyle(fontSize: 14, color: t.textTertiary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: kSpaceXL),
      itemCount: provider.searchResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 0.5,
        thickness: 0.5,
        color: t.border,
        indent: kSpaceLG + kColorStripWidth,
      ),
      itemBuilder: (context, i) {
        final entry = provider.searchResults[i];
        return EntryCard(
          entry: entry,
          onTap: () => context.push('/entry/${entry.id}'),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

// ── Date chip ──────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateChip({
    required this.label,
    required this.isSet,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kAnimFast,
        padding: const EdgeInsets.symmetric(
            horizontal: kSpaceSM, vertical: kSpaceXS),
        decoration: BoxDecoration(
          color: isSet ? t.accentLight : t.surface,
          borderRadius: BorderRadius.circular(kRadiusSM),
          border: Border.all(
            color: isSet ? t.accent.withOpacity(0.4) : t.border,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSet ? t.accent : t.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSet)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: t.accent),
              ),
          ],
        ),
      ),
    );
  }
}