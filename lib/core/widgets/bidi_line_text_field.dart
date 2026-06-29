import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bidi_text/flutter_bidi_text.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Per-Line Bidi Text Field
//  Location: lib/core/widgets/bidi_line_text_field.dart
// ─────────────────────────────────────────────────────────────

/// A multiline text field where each *line* picks its own reading
/// direction from its own content — the way a multi-line WhatsApp or
/// Instagram message shows a Hebrew/Arabic line hugging the right edge
/// and an English line hugging the left edge, simultaneously, in the
/// same message.
///
/// Flutter's text engine doesn't support this natively: a [TextField]
/// (unlike a native Android/iOS text view) always lays out its whole
/// paragraph with a single base direction, so every line shifts
/// together. To get real, simultaneous per-line alignment this widget
/// keeps a single, completely normal, fully-functional [TextField] for
/// all actual editing (so the cursor, selection, IME, autocorrect, and
/// the saved plain-text content are always exactly what they'd
/// normally be — nothing about *data* changes here), and — only once
/// the entry contains any right-to-left content — draws a second,
/// purely visual copy of the text on top of it, line by line, each
/// with its own detected direction. The real field's glyphs are made
/// transparent so only the correctly-aligned copy is visible; its
/// cursor and selection highlight stay fully visible and accurate,
/// since those are painted independently of glyph color.
///
/// For plain left-to-right content (the common case), this is a
/// perfectly ordinary [TextField] with no overlay at all.
class BidiLineTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Color? cursorColor;

  const BidiLineTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.style,
    this.decoration,
    this.autofocus = false,
    this.inputFormatters,
    this.onChanged,
    this.cursorColor,
  });

  @override
  State<BidiLineTextField> createState() => _BidiLineTextFieldState();
}

class _BidiLineTextFieldState extends State<BidiLineTextField> {
  FocusNode? _ownedFocusNode;
  bool _hasRtl = false;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _ownedFocusNode = FocusNode();
    _hasRtl = BidiHelper.detectRtlDirectionality(widget.controller.text);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasRtl = BidiHelper.detectRtlDirectionality(widget.controller.text);
    if (hasRtl != _hasRtl && mounted) {
      setState(() => _hasRtl = hasRtl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        widget.style ?? DefaultTextStyle.of(context).style;

    if (!_hasRtl) {
      // No right-to-left content anywhere in the entry — a perfectly
      // ordinary, fully visible multiline field. Untouched fast path.
      return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        style: effectiveStyle,
        decoration: widget.decoration,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        textAlign: TextAlign.start,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        cursorColor: widget.cursorColor,
      );
    }

    // Mixed/RTL content — overlay a per-line-aligned visual copy on top
    // of a transparent-but-fully-functional real field.
    final contentPadding =
    (widget.decoration?.contentPadding ?? EdgeInsets.zero)
        .resolve(Directionality.of(context));

    return LayoutBuilder(
      builder: (context, constraints) {
        final realField = TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          style: effectiveStyle.copyWith(color: Colors.transparent),
          cursorColor: widget.cursorColor ?? effectiveStyle.color,
          decoration: widget.decoration,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          textAlign: TextAlign.start,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
        );

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Stack(
              // Both the overlay and the real field below are
              // non-positioned, naturally-sized children, so the Stack
              // sizes itself to whichever of the two is taller. Per-line
              // text metrics never match a multiline TextField's metrics
              // *exactly* (small rounding differences compound over many
              // lines), so forcing either layer into a fixed height is
              // what causes overflow — letting both size themselves
              // avoids that regardless of which side is taller.
              children: [
                // Tap anywhere in the empty space below short text to
                // focus the field, matching the old `expands: true`
                // behavior. Sits behind everything in z-order, so it
                // never competes with the field's own tap-to-place
                // -cursor gestures.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _focusNode.requestFocus(),
                  ),
                ),
                IgnorePointer(
                  child: Padding(
                    padding: contentPadding,
                    child: _PerLineOverlay(
                      controller: widget.controller,
                      style: effectiveStyle,
                    ),
                  ),
                ),
                realField,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Renders the controller's text one line at a time, each with its own
/// detected direction and alignment — purely visual, never edited
/// directly.
class _PerLineOverlay extends StatelessWidget {
  final TextEditingController controller;
  final TextStyle style;

  const _PerLineOverlay({required this.controller, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lines = controller.text.split('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines) _LineText(line: line, style: style),
          ],
        );
      },
    );
  }
}

/// A single line of text, aligned to whichever side its own first
/// strong directional character indicates.
class _LineText extends StatelessWidget {
  final String line;
  final TextStyle style;

  const _LineText({required this.line, required this.style});

  @override
  Widget build(BuildContext context) {
    final direction = line.trim().isEmpty
        ? TextDirection.ltr
        : (BidiHelper.estimateDirectionOfText(line) ?? TextDirection.ltr);

    return SizedBox(
      width: double.infinity,
      child: Text(
        // An empty string can collapse to zero height in some styles;
        // a single space keeps each blank line's vertical rhythm
        // identical to the real field's.
        line.isEmpty ? ' ' : line,
        style: style,
        textDirection: direction,
        textAlign: direction == TextDirection.rtl ? TextAlign.right : TextAlign.left,
        softWrap: true,
      ),
    );
  }
}