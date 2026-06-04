import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Appearance Screen
//  Location: lib/screens/settings/appearance_screen.dart
//
//  Order:
//    1. Editable preview canvas        ← font changes live here
//    2. Title font  (horizontal chips)
//    3. Body font   (horizontal chips)
//    4. Size & Spacing (segment toggles)
//    5. Colours  (3×3 circle swatches inside an app-style card)
//
//  Colour picker:
//    Bottom sheet with a local StatefulWidget that holds its own
//    HSVColor state.  The wheel and sliders only call setState on
//    *themselves* — ThemeProvider.setColor() is called once, on
//    "Apply", so the main ListView never rebuilds during dragging.
//    This makes the picker buttery-smooth.
// ─────────────────────────────────────────────────────────────

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late final TextEditingController _bodyCtrl;
  static const _sampleBody =
      'The afternoon stretched long and golden, '
      'unhurried as a Sunday with nowhere to be.';

  @override
  void initState() {
    super.initState();
    _bodyCtrl = TextEditingController(text: _sampleBody);
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
    final tp = context.watch<ThemeProvider>();
    final fp = tp.currentFontPairData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: AppIconSize.xs,
              color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Appearance',
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [

          // 1 ── Editable preview canvas ─────────────────────
          _PreviewCanvas(ctrl: _bodyCtrl, tp: tp),

          // 2 ── Title font ──────────────────────────────────
          const _SectionRow(label: 'Title font'),
          _FontRow(
            fonts:    PoppyFonts.all,
            selected: tp.currentTitleFont,
            onSelect: tp.setTitleFont,
          ),

          // 3 ── Body font ───────────────────────────────────
          const _SectionRow(label: 'Body font'),
          _FontRow(
            fonts:    PoppyFonts.all,
            selected: tp.currentBodyFont,
            onSelect: tp.setBodyFont,
          ),

          // 5 ── Colours ─────────────────────────────────────
          _SectionRow(
            label: 'App Colours',
            trailing: tp.hasAnyCustomColor
                ? _ResetAllButton(tp: tp)
                : null,
          ),
          _ColorCard(tp: tp),

          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg),
            child: Text(
              'Long-press any colour swatch to reset it to default.',
              style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Preview canvas
// ─────────────────────────────────────────────────────────────

class _PreviewCanvas extends StatelessWidget {
  final TextEditingController ctrl;
  final ThemeProvider         tp;
  const _PreviewCanvas({required this.ctrl, required this.tp});

  @override
  Widget build(BuildContext context) {
    final t     = context.poppyTheme;
    final fp    = tp.currentFontPairData;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color:        t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // fake entry header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: t.accentLight,
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color:        t.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                alignment: Alignment.center,
                child: Text('${DateTime.now().day}',
                    style: AppTextStyles.calendarDay(t.accent, fp)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Preview',
                  style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Text('A quiet morning',
                style: fp.titleFont.bold(t.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 6),
            child: Divider(height: AppStroke.hairline,
                thickness: AppStroke.hairline, color: t.border),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: TextField(
              controller:   ctrl,
              style:        fp.bodyFont.style(t.textPrimary),
              maxLines:     null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border:         InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText:       'Tap to write a sample…',
                hintStyle:      fp.bodyFont.style(t.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Font row
// ─────────────────────────────────────────────────────────────

class _FontRow extends StatelessWidget {
  final List<PoppyFontData>     fonts;
  final PoppyFont               selected;
  final ValueChanged<PoppyFont> onSelect;
  const _FontRow({required this.fonts, required this.selected,
    required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: fonts.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final f   = fonts[i];
          final sel = f.id == selected;
          return GestureDetector(
            onTap: () => onSelect(f.id),
            child: AnimatedContainer(
              duration: AppDuration.normal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical:   AppSpacing.sm),
              decoration: BoxDecoration(
                color: sel ? t.accentLight : t.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: sel ? t.accent : t.border,
                  width: sel
                      ? AppStroke.medium
                      : AppStroke.hairline,
                ),
              ),
              child: Column(
                mainAxisAlignment:  MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.displayName,
                      style: f.bold(
                          sel ? t.accent : t.textPrimary,
                          size: 13, height: 1.2)),
                  const SizedBox(height: 3),
                  Text(f.tagline,
                      style: AppTextStyles.labelLargeSans(
                        sel
                            ? t.accent.withOpacity(0.7)
                            : t.textTertiary, fp,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  final String             label;
  final List<T>            options;
  final T                  current;
  final String Function(T) labelOf;
  final void   Function(T) onSelect;
  const _SegmentRow({required this.label, required this.options,
    required this.current, required this.labelOf,
    required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(children: [
        SizedBox(width: 64,
            child: Text(label,
                style: AppTextStyles.titleSmallSans(t.textPrimary, fp))),
        Expanded(
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color:        t.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                  color: t.border, width: AppStroke.hairline),
            ),
            child: Row(
              children: options.map((opt) {
                final sel = opt == current;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(opt),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: sel ? t.accent : Colors.transparent,
                        borderRadius:
                        BorderRadius.circular(AppRadius.xs),
                      ),
                      alignment: Alignment.center,
                      child: Text(labelOf(opt),
                          style: AppTextStyles.titleSmallSans(
                            sel ? Colors.white : t.textSecondary, fp,
                          ).copyWith(
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Colour card — Wrap of circle swatches, no surplus space
//  3 per row, each cell sized tightly to circle + label.
// ─────────────────────────────────────────────────────────────

class _ColorCard extends StatelessWidget {
  final ThemeProvider tp;
  const _ColorCard({required this.tp});

  static const _swatchSize  = 44.0;
  static const _cellWidth   = 80.0;

  @override
  Widget build(BuildContext context) {
    final t     = context.poppyTheme;
    final slots = ColorSlots.all;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color:        t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Wrap(
        alignment:      WrapAlignment.spaceEvenly,
        spacing:        0,
        runSpacing:     AppSpacing.md,
        children: slots.map((slot) {
          final color    = tp.colorFor(slot);
          final isCustom = tp.isCustomized(slot);
          return SizedBox(
            width: _cellWidth,
            child: _ColorSwatch(
              swatchSize: _swatchSize,
              slot:       slot,
              color:      color,
              isCustom:   isCustom,
              onTap:      () => _openPicker(context, slot, color, tp),
              onReset:    isCustom ? () => tp.resetColor(slot) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openPicker(BuildContext context, ColorSlot slot,
      Color initial, ThemeProvider tp) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      useRootNavigator:   true,
      builder: (_) => _ColorPickerSheet(
        slot:    slot,
        initial: initial,
        onApply: (c) => tp.setColor(slot, c),
        onReset: () => tp.resetColor(slot),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Individual circle swatch
// ─────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final ColorSlot     slot;
  final Color         color;
  final bool          isCustom;
  final double        swatchSize;
  final VoidCallback  onTap;
  final VoidCallback? onReset;

  const _ColorSwatch({
    required this.slot,
    required this.color,
    required this.isCustom,
    required this.swatchSize,
    required this.onTap,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final t       = context.poppyTheme;
    final ringSize = swatchSize + 6;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return GestureDetector(
      onTap:       onTap,
      onLongPress: onReset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Ring — only visible when customised
              AnimatedContainer(
                duration: AppDuration.fast,
                width: ringSize, height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCustom
                        ? t.accent.withOpacity(0.45)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              // The colour circle
              Container(
                width: swatchSize, height: swatchSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: t.border,
                    width: AppStroke.hairline,
                  ),
                ),
              ),
              // Tiny edited dot — top right
              if (isCustom)
                Positioned(
                  right: 1, top: 1,
                  child: Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent,
                      border: Border.all(color: t.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            slot.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppTextStyles.labelLargeSans(
              isCustom ? t.accent : t.textTertiary, fp,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reset all button
// ─────────────────────────────────────────────────────────────

class _ResetAllButton extends StatelessWidget {
  final ThemeProvider tp;
  const _ResetAllButton({required this.tp});

  @override
  Widget build(BuildContext context) {
    final fp = context.read<ThemeProvider>().currentFontPairData;

  return GestureDetector(
      onTap: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title:   const Text('Reset all colours?'),
            content: const Text('This restores the Poppy defaults.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) tp.resetAllColors();
      },
      child: Text('Reset all',
          style: AppTextStyles.labelLargeSans(AppColors.error, fp)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Color picker bottom sheet
//
//  UX design:
//  Instead of an HSV wheel (complex, laggy, hard to learn),
//  we show a curated palette of 40 handpicked colours grouped
//  by hue — the same pattern as Notion, Linear, and iOS Notes.
//  The user taps a swatch → instant, zero drag, zero lag.
//
//  Below the palette is a hex input field for power users who
//  know their exact colour code.  The live preview circle in
//  the header updates immediately on every tap or valid hex.
//
//  Performance: only this sheet's State rebuilds. ThemeProvider
//  is called once on "Apply".
// ─────────────────────────────────────────────────────────────

class _ColorPickerSheet extends StatefulWidget {
  final ColorSlot            slot;
  final Color                initial;
  final void Function(Color) onApply;
  final VoidCallback         onReset;

  const _ColorPickerSheet({
    required this.slot,
    required this.initial,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _current;
  late final TextEditingController _hexCtrl;
  bool _hexValid = true;

  static const _cols = 9;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _hexCtrl = TextEditingController(
        text: _colorToHex(_current));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) {
    return '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _pick(Color c) {
    setState(() {
      _current  = c;
      _hexValid = true;
      _hexCtrl.text = _colorToHex(c);
    });
  }

  void _onHexChanged(String raw) {
    final h = raw.replaceAll('#', '').trim();
    if (h.length == 6) {
      try {
        final c = Color(int.parse('FF$h', radix: 16));
        setState(() { _current = c; _hexValid = true; });
        return;
      } catch (_) {}
    }
    setState(() => _hexValid = h.isEmpty || h.length < 6);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Container(
      decoration: BoxDecoration(
        color:        t.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg)),
        border: Border(
            top: BorderSide(color: t.border,
                width: AppStroke.hairline)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            AppSpacing.lg,
        top:   AppSpacing.sm,
        left:  AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width:  AppComponentSize.sheetHandle,
                  height: AppComponentSize.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius:
                    BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header: slot label + description + live swatch
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.slot.label,
                          style: AppTextStyles.titleSmallSans(
                              t.textPrimary, fp)
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(widget.slot.description,
                          style: AppTextStyles.labelLargeSans(
                              t.textTertiary, fp)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape:  BoxShape.circle,
                    color:  _current,
                    border: Border.all(
                        color: t.border,
                        width: AppStroke.hairline),
                  ),
                ),
              ]),

              const SizedBox(height: AppSpacing.md),

              // ── Palette grid ────────────────────────────────
              LayoutBuilder(builder: (_, box) {
                final cellSize = (box.maxWidth - (_cols - 1) * 4) / _cols;
                return Wrap(
                  spacing:    4,
                  runSpacing: 4,
                  children: AppColors.colorPalette.map((c) {
                    final sel = c.value == _current.value;
                    return GestureDetector(
                      onTap: () => _pick(c),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width:  cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color:        c,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: sel
                                ? t.textPrimary.withOpacity(0.7)
                                : Colors.black.withOpacity(0.08),
                            width: sel ? 2.5 : 0.5,
                          ),
                        ),
                        child: sel
                            ? Icon(AppIcons.check,
                            size: cellSize * 0.5,
                            color: c.computeLuminance() > 0.35
                                ? Colors.black54
                                : Colors.white70)
                            : null,
                      ),
                    );
                  }).toList(),
                );
              }),

              const SizedBox(height: AppSpacing.md),

              // ── Hex input ────────────────────────────────────
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:  _current,
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: t.border,
                        width: AppStroke.hairline),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller:  _hexCtrl,
                    onChanged:   _onHexChanged,
                    style:       AppTextStyles.bodySmallSans(t.textPrimary, fp),
                    decoration: InputDecoration(
                      hintText:     '#RRGGBB',
                      hintStyle:    AppTextStyles.bodySmallSans(
                          t.textTertiary, fp),
                      isDense:      true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical:   AppSpacing.sm),
                      filled:       true,
                      fillColor:    t.background,
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                            color: _hexValid ? t.border : AppColors.error,
                            width: AppStroke.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                            color: _hexValid ? t.border : AppColors.error,
                            width: AppStroke.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                            color: _hexValid ? t.accent : AppColors.error,
                            width: AppStroke.medium),
                      ),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: AppSpacing.md),

              // ── Buttons ──────────────────────────────────────
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onReset();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textSecondary,
                      side: BorderSide(color: t.border),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(AppRadius.sm)),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      widget.onApply(_current);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _current,
                      foregroundColor:
                      _current.computeLuminance() > 0.35
                          ? Colors.black87
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(AppRadius.sm)),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Section row with optional trailing
// ─────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String  label;
  final Widget? trailing;
  const _SectionRow({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg,
        AppSpacing.lg, AppSpacing.xs,
      ),
      child: Row(children: [
        Expanded(
          child: Text(label.toUpperCase(),
              style: AppTextStyles.labelSmall(t.textTertiary, fp)
                  .copyWith(letterSpacing: 0.8)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}