import 'package:flutter/material.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/color_dot.dart';
import 'package:poppy/core/widgets/entry_card.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  EntryColorData? _selectedColor;
  DateTime?       _fromDate;
  DateTime?       _toDate;
  bool            _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    context.read<EntriesProvider>().clearSearch();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() => _hasSearched = true);
    await context.read<EntriesProvider>().search(
      query: _searchController.text.trim(),
      colorTag: _selectedColor?.dbValue,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _selectedColor = null;
      _fromDate      = null;
      _toDate        = null;
      _hasSearched   = false;
    });
    context.read<EntriesProvider>().clearSearch();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final t   = context.poppyTheme;
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
    setState(() => isFrom ? _fromDate = picked : _toDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t        = context.poppyTheme;
    final provider = context.watch<EntriesProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Search', style: AppTextStyles.appBarTitle(t.textPrimary)),
        actions: [
          if (_hasSearched || _selectedColor != null || _fromDate != null || _toDate != null)
            TextButton(
              onPressed: _clearAll,
              child: Text('Clear', style: AppTextStyles.link(t.accent)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: t.border, width: AppStroke.hairline),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTextStyles.fieldText(t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search entries…',
                  hintStyle: AppTextStyles.searchHint(t.textTertiary),
                  prefixIcon: Icon(AppIcons.search,
                      size: AppIconSize.sm, color: t.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                onSubmitted: (_) => _runSearch(),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: EntryColors.all.map((colorData) {
                final isSelected = _selectedColor?.id == colorData.id;
                return GestureDetector(
                  onTap: () => setState(() =>
                  _selectedColor = isSelected ? null : colorData),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    margin: const EdgeInsets.only(
                        right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (colorData.color as Color).withOpacity(0.12)
                          : t.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: isSelected ? colorData.color as Color : t.border,
                        width: isSelected ? AppStroke.medium : AppStroke.hairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ColorDot(colorData: colorData,
                            size: AppComponentSize.colorDotChip, isSelected: false),
                        const SizedBox(width: AppSpacing.xs),
                        Text(colorData.name,
                            style: AppTextStyles.searchFilterChip(
                              isSelected ? colorData.color as Color : t.textSecondary,
                              selected: isSelected,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: _fromDate == null
                        ? 'From date'
                        : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                    isSet: _fromDate != null,
                    onTap: () => _pickDate(isFrom: true),
                    onClear: () => setState(() => _fromDate = null),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _DateChip(
                    label: _toDate == null
                        ? 'To date'
                        : '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',
                    isSet: _toDate != null,
                    onTap: () => _pickDate(isFrom: false),
                    onClear: () => setState(() => _toDate = null),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _runSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text('Search', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, color: t.border),
          Expanded(
            child: provider.isSearching
                ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: t.accent))
                : !_hasSearched
                ? Center(
              child: Text(
                'Enter a term or pick a filter\nthen tap Search.',
                textAlign: TextAlign.center,
                style: AppTextStyles.emptySubtitle(t.textTertiary)
                    .copyWith(height: 1.6),
              ),
            )
                : provider.searchResults.isEmpty
                ? Center(
              child: Text('No entries found.',
                  style: AppTextStyles.emptySubtitle(t.textTertiary)),
            )
                : ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: provider.searchResults.length,
              separatorBuilder: (_, __) => Divider(
                height: AppStroke.hairline,
                thickness: AppStroke.hairline,
                color: t.border,
                indent: AppSpacing.lg + AppStroke.colorStrip,
              ),
              itemBuilder: (context, i) {
                final entry = provider.searchResults[i];
                return EntryCard(
                  entry: entry,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.write, arguments: entry.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateChip({
    required this.label, required this.isSet,
    required this.onTap, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSet ? t.accentLight : t.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSet ? t.accent.withOpacity(0.4) : t.border,
            width: AppStroke.hairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.searchFilterChip(
                      isSet ? t.accent : t.textTertiary),
                  overflow: TextOverflow.ellipsis),
            ),
            if (isSet)
              GestureDetector(
                onTap: onClear,
                child: Icon(AppIcons.close, size: AppIconSize.xs, color: t.accent),
              ),
          ],
        ),
      ),
    );
  }
}
