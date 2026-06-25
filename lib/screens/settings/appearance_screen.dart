import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Appearance Screen
//  Location: lib/screens/settings/appearance_screen.dart
// ─────────────────────────────────────────────────────────────

/// Allows users to customize the visual style of the application.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late final TextEditingController _bodyCtrl;
  static const _sampleBody = 'The quick brown fox jumps over the lazy dog.';

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
    final t = context.poppyTheme;
    final tp = context.watch<ThemeProvider>();
    final fp = tp.currentFontPairData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Appearance',
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // ── Preview canvas ────────────────────────────────
          _PreviewCanvas(ctrl: _bodyCtrl, tp: tp),

          // ── Title font ────────────────────────────────────
          const _SectionRow(label: 'Title font'),
          _FontRow(
            fonts: PoppyFonts.all,
            selected: tp.currentTitleFont,
            onSelect: tp.setTitleFont,
          ),

          // ── Body font ─────────────────────────────────────
          const _SectionRow(label: 'Body font'),
          _FontRow(
            fonts: PoppyFonts.all,
            selected: tp.currentBodyFont,
            onSelect: tp.setBodyFont,
          ),

          // ── Colours ───────────────────────────────────────
          _SectionRow(
            label: 'App Colors',
            trailing:
            tp.hasAnyCustomColor ? _ResetAllButton(tp: tp) : null,
          ),
          _ColorCard(tp: tp),

          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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

// ── sub‑widgets ──────────────────────────────────────────────

class _PreviewCanvas extends StatelessWidget {
  final TextEditingController ctrl;
  final ThemeProvider tp;
  const _PreviewCanvas({required this.ctrl, required this.tp});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = tp.currentFontPairData;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: t.accentLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.15),
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
            child: Divider(
                height: AppStroke.hairline,
                thickness: AppStroke.hairline,
                color: t.border),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),

            child: TextField(
              controller: ctrl,
              style: fp.bodyFont.style(t.textPrimary),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Tap to write a sample…',
                hintStyle: fp.bodyFont.style(t.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  final List<PoppyFontData> fonts;
  final PoppyFont selected;
  final ValueChanged<PoppyFont> onSelect;
  const _FontRow(
      {required this.fonts, required this.selected, required this.onSelect});

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
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final f = fonts[i];
          final sel = f.id == selected;
          return GestureDetector(
            onTap: () => onSelect(f.id),
            child: AnimatedContainer(
              duration: AppDuration.normal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: sel ? t.accentLight : t.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: sel ? t.accent : t.border,
                  width: sel ? AppStroke.medium : AppStroke.hairline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.displayName,
                      style: f.bold(sel ? t.accent : t.textPrimary,
                          size: 13, height: 1.2)),
                  const SizedBox(height: 3),
                  Text(f.tagline,
                      style: AppTextStyles.labelLargeSans(
                        sel
                            ? t.accent.withValues(alpha: 0.7)
                            : t.textTertiary,
                        fp,
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

class _ColorCard extends StatelessWidget {
  final ThemeProvider tp;
  const _ColorCard({required this.tp});

  static const _swatchSize = 44.0;
  static const _cellWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    const slots = ColorSlots.all;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 0,
        runSpacing: AppSpacing.md,
        children: slots.map((slot) {
          final color = tp.colorFor(slot);
          final isCustom = tp.isCustomized(slot);
          return SizedBox(
            width: _cellWidth,
            child: _ColorSwatch(
              swatchSize: _swatchSize,
              slot: slot,
              color: color,
              isCustom: isCustom,
              onTap: () => _openPicker(context, slot, color, tp),
              onReset: isCustom ? () => tp.resetColor(slot) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openPicker(
      BuildContext context, ColorSlot slot, Color initial, ThemeProvider tp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (_) => ColorPickerSheet(
        title: slot.label,
        description: slot.description,
        initialColor: initial,
        onApply: (c) {
          tp.setColor(slot, c);
          return true;
        },
        onReset: () => tp.resetColor(slot),
        showReset: true,
        showCancel: false,
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final ColorSlot slot;
  final Color color;
  final bool isCustom;
  final double swatchSize;
  final VoidCallback onTap;
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
    final t = context.poppyTheme;
    final ringSize = swatchSize + 6;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onReset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: AppDuration.fast,
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCustom
                        ? t.accent.withValues(alpha: 0.45)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: swatchSize,
                height: swatchSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: t.border,
                    width: AppStroke.hairline,
                  ),
                ),
              ),
              if (isCustom)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 9,
                    height: 9,
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
              isCustom ? t.accent : t.textTertiary,
              fp,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ResetAllButton extends StatelessWidget {
  final ThemeProvider tp;
  const _ResetAllButton({required this.tp});

  @override
  Widget build(BuildContext context) {
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return GestureDetector(
      onTap: () async {
        final ok = await PoppyDialog.showDestructive(
          context,
          title: 'Reset all colours?',
          confirmLabel: 'Reset',
          message: "This restores the Poppy defaults. Any custom colours you've set will be lost.",
        );
        if (ok == true && context.mounted) tp.resetAllColors();
      },
      child: Text('Reset all',
          style: AppTextStyles.labelLargeSans(AppColors.error, fp)),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionRow({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}