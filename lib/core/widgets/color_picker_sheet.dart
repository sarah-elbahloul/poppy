import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// A reusable bottom sheet for picking a colour.
///
/// In its simplest form (e.g. the Appearance screen) you only pass
/// [title], [description], [initialColor], [onApply] and [onReset].
///
/// For richer editors (e.g. the Tag screen) set [showCancel], custom
/// [applyLabel], and supply [extraFields] – a builder that receives the
/// sheet's [BuildContext] so it can read theme / providers and inject
/// additional widgets **below** the hex‑code row.
class ColorPickerSheet extends StatefulWidget {
  /// Header text shown in bold.
  final String title;

  /// Smaller text beneath the title.
  final String? description;

  /// Starting colour.
  final Color initialColor;

  /// Called when the user taps **Apply**.
  /// Return `true` to dismiss the sheet, `false` to keep it open
  /// (useful when extra‑field validation fails).
  final bool Function(Color color)? onApply;

  /// Called when the user taps **Reset**, then the sheet closes.
  final VoidCallback? onReset;

  /// Called when the user taps **Cancel**, then the sheet closes.
  final VoidCallback? onCancel;

  /// Whether to show the Reset button.
  final bool showReset;

  /// Whether to show the Cancel button.
  final bool showCancel;

  /// Label for the primary (right‑most) button.
  final String applyLabel;

  /// Label for the Reset button (defaults to "Reset").
  final String? resetLabel;

  /// Label for the Cancel button (defaults to "Cancel").
  final String? cancelLabel;

  /// Optional builder invoked **below** the hex‑code field.
  /// Receives the sheet's [BuildContext] so it can access
  /// theme data, providers, etc.
  final WidgetBuilder? extraFields;

  const ColorPickerSheet({
    super.key,
    required this.title,
    this.description,
    required this.initialColor,
    this.onApply,
    this.onReset,
    this.onCancel,
    this.showReset = true,
    this.showCancel = false,
    this.applyLabel = 'Apply',
    this.resetLabel,
    this.cancelLabel,
    this.extraFields,
  });

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color _current;
  late TextEditingController _hexCtrl;
  bool _hexValid = true;
  bool _showWheel = false;

  static const _cols = 9;

  @override
  void initState() {
    super.initState();
    _current = widget.initialColor;
    _hexCtrl = TextEditingController(text: _colorToHex(_current));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────

  String _colorToHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _pick(Color c) {
    setState(() {
      _current = c;
      _hexValid = true;
      _hexCtrl.text = _colorToHex(c);
    });
  }

  void _onHexChanged(String raw) {
    final h = raw.replaceAll('#', '').trim();
    if (h.length == 6) {
      try {
        final c = Color(int.parse('FF$h', radix: 16));
        setState(() {
          _current = c;
          _hexValid = true;
        });
        return;
      } catch (_) {}
    }
    setState(() => _hexValid = h.isEmpty || h.length < 6);
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;
    final onDark = _current.computeLuminance() < 0.35;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        border: Border(
          top: BorderSide(color: t.border, width: AppStroke.hairline),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        top: AppSpacing.sm,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── drag handle ──────────────────────────────
              Center(
                child: Container(
                  width: AppComponentSize.sheetHandle,
                  height: AppComponentSize.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── header row (title + colour orb) ─────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.titleSmallSans(
                            t.textPrimary,
                            fp,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (widget.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.description!,
                            style: AppTextStyles.labelLargeSans(
                              t.textTertiary,
                              fp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showWheel = !_showWheel),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _current,
                        border: Border.all(
                          color: _showWheel
                              ? t.accent
                              : t.accent.withValues(alpha: 0.4),
                          width:
                          _showWheel ? AppStroke.thick : AppStroke.medium,
                        ),
                      ),
                      child: Icon(
                        AppIcons.color,
                        size: 18,
                        color: onDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── colour wheel (animated) ──────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: AppCurve.enter,
                alignment: Alignment.topCenter,
                child: _showWheel
                    ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: ColorWheel(
                    initialColor: _current,
                    onChanged: (c) {
                      setState(() {
                        _current = c;
                        _hexCtrl.text = _colorToHex(c);
                        _hexValid = true;
                      });
                    },
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              // ── palette grid ────────────────────────────
              LayoutBuilder(builder: (_, box) {
                final cellSize = (box.maxWidth - (_cols - 1) * 4) / _cols;

                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: AppColors.colorPalette.map((c) {
                    final sel = c.toARGB32() == _current.toARGB32();

                    return GestureDetector(
                      onTap: () => _pick(c),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: sel
                                ? t.textPrimary.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.08),
                            width:
                            sel ? AppStroke.medium : AppStroke.thin,
                          ),
                        ),
                        child: sel
                            ? Icon(
                          AppIcons.check,
                          size: cellSize * 0.5,
                          color: c.computeLuminance() > 0.35
                              ? Colors.black54
                              : Colors.white70,
                        )
                            : null,
                      ),
                    );
                  }).toList(),
                );
              }),

              const SizedBox(height: AppSpacing.md),

              // ── hex code row ────────────────────────────
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _current,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.border,
                        width: AppStroke.hairline,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _hexCtrl,
                      onChanged: _onHexChanged,
                      style: AppTextStyles.bodySmallSans(t.textPrimary, fp),
                      decoration: InputDecoration(
                        hintText: '#RRGGBB',
                        hintStyle:
                        AppTextStyles.bodySmallSans(t.textTertiary, fp),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        filled: true,
                        fillColor: t.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: _hexValid ? t.border : AppColors.error,
                            width: AppStroke.hairline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: _hexValid ? t.border : AppColors.error,
                            width: AppStroke.hairline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: _hexValid ? t.accent : AppColors.error,
                            width: AppStroke.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── extra fields injected by the caller ─────
              if (widget.extraFields != null) ...[
                widget.extraFields!(context),
              ],

              const SizedBox(height: AppSpacing.md),

              // ── button row ──────────────────────────────
              _buildButtonRow(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonRow(PoppyThemeExtension t) {
    final children = <Widget>[];

    if (widget.showCancel) {
      children.add(
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              widget.onCancel?.call();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: t.textSecondary,
              side: BorderSide(color: t.textSecondary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Text(widget.cancelLabel ?? 'Cancel'),
          ),
        ),
      );
    }

    if (widget.showReset) {
      if (children.isNotEmpty) children.add(const SizedBox(width: AppSpacing.sm));
      children.add(
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              widget.onReset?.call();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: t.textSecondary,
              side: BorderSide(color: t.textSecondary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Text(widget.resetLabel ?? 'Reset'),
          ),
        ),
      );
    }

    if (widget.onApply != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: AppSpacing.sm));
      children.add(
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: () {
              final shouldClose = widget.onApply!(_current);
              if (shouldClose) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: t.background,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Text(widget.applyLabel),
          ),
        ),
      );
    }

    return Row(children: children);
  }
}