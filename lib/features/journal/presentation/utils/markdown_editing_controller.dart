import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/presentation/utils/markdown_list_formatter.dart';

/// A [TextEditingController] that renders markdown syntax with live styling.
///
/// Characters remain unchanged in [text] — only visual styling is applied via
/// [buildTextSpan]. This preserves cursor/selection correctness.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({
    TextStyle baseStyle = const TextStyle(fontSize: 16, height: 1.6),
    FontPairData? fontPair,
    Color accentColor = const Color(0xFF6B6B6B),
    Color mutedColor = const Color(0xFF9A9A9A),
    String? text,
  })  : _baseStyle = baseStyle,
        _fontPair = fontPair,
        _accentColor = accentColor,
        _mutedColor = mutedColor,
        super(text: text);

  TextStyle _baseStyle;
  FontPairData? _fontPair;
  Color _accentColor;
  Color _mutedColor;

  /// Updates theme-dependent styles. Call from `build()` once context is available.
  void updateStyleContext({
    required TextStyle baseStyle,
    required FontPairData fontPair,
    required Color accentColor,
    required Color mutedColor,
  }) {
    _baseStyle = baseStyle;
    _fontPair = fontPair;
    _accentColor = accentColor;
    _mutedColor = mutedColor;
  }

  static final RegExp _headingRegex = RegExp(r'^(#{1,3})(\s+)(.*)$');
  static final RegExp _hrRegex = RegExp(r'^(\s*)(─{3,})$');
  static final RegExp _inlineRegex = RegExp(
    r'(\*\*[^\n]+?\*\*)' // Bold **
    r'|(__[^\n]+?__)'    // Bold __
    r'|(~~[^\n]+?~~)'   // Strike
    r'|(`[^`\n]+?`)'    // Code
    r'|(\*[^\s*][^\n]*?\*)' // Italic *
    r'|(_[^\s_][^\n]*?_)', // Italic _
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = _baseStyle.merge(style);
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    int lineStartOffset = 0;
    for (var i = 0; i < lines.length; i++) {
      spans.addAll(_buildLineSpans(lines[i], base, lineStartOffset, context));
      lineStartOffset += lines[i].length + 1; // +1 for '\n'

      if (i != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: base));
      }
    }

    return TextSpan(style: base, children: spans);
  }

  List<InlineSpan> _buildLineSpans(
      String line,
      TextStyle base,
      int lineStartOffset,
      BuildContext context,
      ) {
    // 1. Horizontal Rule
    final hrMatch = _hrRegex.firstMatch(line);
    if (hrMatch != null) {
      return [
        TextSpan(
          text: line,
          style: base.copyWith(
            color: _mutedColor.withOpacity(0.4),
            letterSpacing: 4,
            fontWeight: FontWeight.w300,
          ),
        ),
      ];
    }

    // 2. Heading
    final headingMatch = _headingRegex.firstMatch(line);
    if (headingMatch != null) {
      return _buildHeadingSpans(headingMatch, line, base);
    }

    // 3. List Item / Checkbox / Quote
    final listMatch = MarkdownListFormatter.lineMarkerRegex.firstMatch(line);
    if (listMatch != null) {
      return _buildListSpans(listMatch, line, base, lineStartOffset, context);
    }

    // 4. Regular Text with Inline Styles
    return _buildInlineSpans(line, base);
  }

  List<InlineSpan> _buildHeadingSpans(
      RegExpMatch match,
      String line,
      TextStyle base,
      ) {
    final hashes = match.group(1)!;
    final gap = match.group(2)!;
    final content = match.group(3)!;

    final double size = switch (hashes.length) {
      1 => 26.0,
      2 => 22.0,
      _ => 19.0,
    };

    final headingStyle = _fontPair != null
        ? _fontPair!.titleFont.bold(
      base.color ?? Colors.black,
      size: size,
      height: 1.3,
    )
        : base.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );

    return [
      TextSpan(
        text: hashes + gap,
        style: base.copyWith(
          color: _mutedColor.withOpacity(0.4),
          fontWeight: FontWeight.w400,
          fontSize: size * 0.7,
        ),
      ),
      ..._buildInlineSpans(content, headingStyle),
    ];
  }

  List<InlineSpan> _buildListSpans(
      RegExpMatch match,
      String line,
      TextStyle base,
      int lineStartOffset,
      BuildContext context,
      ) {
    final indent = match.group(1)!;
    final marker = match.group(2)!;
    final rest = line.substring(match.end);
    final isChecked = marker == MarkdownListFormatter.checkboxDoneMarker;
    final isCheckbox =
        marker == MarkdownListFormatter.checkboxEmptyMarker || isChecked;
    final isQuote = marker.trim() == '>';

    if (isCheckbox) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: base),
        // The two raw marker characters ('☐'/'☑' + trailing space) stay in
        // the text but are rendered with zero visual footprint; the
        // WidgetSpan below draws the actual checkbox in their place.
        //
        // IMPORTANT: this checkbox is purely decorative (wrapped in
        // IgnorePointer) and must NOT own its own tap handler. This span
        // lives inside an editable TextField, and a GestureDetector here
        // would win the gesture arena over the TextField's own
        // tap-to-place-caret recognizer, "swallowing" taps that land on the
        // checkbox's pixels — that mismatch (checkbox looks tappable but
        // the field's real tap handler never runs for it) is what made
        // toggling feel inconsistent. Toggling is instead handled once the
        // caret lands, via the field's onTap callback — see
        // `_handleChecklistTap` in write_screen.dart — which is the single
        // source of truth for checkbox taps.
        TextSpan(
          text: marker,
          style: base.copyWith(fontSize: 0.01, color: Colors.transparent),
        ),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(right: 8, left: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isChecked ? _accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isChecked ? _accentColor : _mutedColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
        ..._buildInlineSpans(
          rest,
          isChecked
              ? base.copyWith(
            color: _mutedColor,
            decoration: TextDecoration.lineThrough,
            decorationColor: _mutedColor.withOpacity(0.5),
          )
              : base,
        ),
      ];
    }

    if (isQuote) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: base),
        TextSpan(
          text: '▎ ', // Visual indicator
          style: base.copyWith(
            color: _accentColor.withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        ..._buildInlineSpans(
          rest,
          base.copyWith(
            color: base.color?.withOpacity(0.85),
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    return [
      if (indent.isNotEmpty) TextSpan(text: indent, style: base),
      TextSpan(
        text: marker,
        style: base.copyWith(
          color: _accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      ..._buildInlineSpans(rest, base),
    ];
  }

  List<InlineSpan> _buildInlineSpans(String text, TextStyle base) {
    if (text.isEmpty) return [TextSpan(text: text, style: base)];

    final spans = <InlineSpan>[];
    var last = 0;

    for (final m in _inlineRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }

      final full = m.group(0)!;

      if (m.group(1) != null || m.group(2) != null) {
        // Bold
        final delim = full.startsWith('**') ? '**' : '__';
        spans.add(TextSpan(
          text: full.substring(delim.length, full.length - delim.length),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (m.group(3) != null) {
        // Strike
        spans.add(TextSpan(
          text: full.substring(2, full.length - 2),
          style: base.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: base.color?.withOpacity(0.6),
          ),
        ));
      } else if (m.group(4) != null) {
        // Code
        spans.add(TextSpan(
          text: full,
          style: base.copyWith(
            fontFamily: 'monospace',
            color: _accentColor,
            backgroundColor: _accentColor.withOpacity(0.08),
          ),
        ));
      } else if (m.group(5) != null || m.group(6) != null) {
        // Italic
        spans.add(TextSpan(
          text: full.substring(1, full.length - 1),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      }

      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }
}
