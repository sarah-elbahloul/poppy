import 'package:flutter/services.dart';

/// A [TextInputFormatter] that converts markdown list shortcuts to Unicode
/// markers on space, and handles continuation/exit on Enter and Backspace.
///
/// Shortcuts (triggered by trailing space):
/// - `- `, `* ` → bullet (`•`, `◦`, or `▪` based on indent depth)
/// - `[] `, `[ ] ` → empty checkbox (`☐`)
/// - `[x] `, `[X] ` → checked checkbox (`☑`)
/// - `> ` → blockquote marker (`> `)
/// - `--- `, `*** `, `___ ` → horizontal rule (`───`)
/// - `1. `, `2. `, ... → numbered (continues on Enter, resets on indent)
class MarkdownListFormatter extends TextInputFormatter {
  static const List<String> bulletGlyphs = ['• ', '◦ ', '▪ '];
  static const String checkboxEmptyMarker = '☐ ';
  static const String checkboxDoneMarker = '☑ ';
  static const String blockquoteMarker = '> ';
  static const String hrMarker = '───';

  /// Matches a list-item prefix: optional indent, then bullet/checkbox/number/quote/hr.
  static final RegExp lineMarkerRegex =
      RegExp(r'^( *)(• |◦ |▪ |☐ |☑ |> |───|\d{1,9}\. )');

  static final RegExp _numberedMarkerExact = RegExp(r'^(\d{1,9})\. $');
  static const int maxIndentSteps = 4;

  static bool isBulletMarker(String marker) => bulletGlyphs.contains(marker);

  static String bulletForDepth(int depth) =>
      bulletGlyphs[depth.clamp(0, bulletGlyphs.length - 1)];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selection = newValue.selection;
    if (!selection.isValid || !selection.isCollapsed) return newValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final cursor = selection.baseOffset;
    final isInsertion = newValue.text.length == oldValue.text.length + 1;
    final isDeletion = oldValue.text.length == newValue.text.length + 1;

    if (isInsertion) {
      final insertedChar = newValue.text[cursor - 1];
      if (insertedChar == '\n') {
        return _handleEnter(newValue.text, cursor) ?? newValue;
      }
      if (insertedChar == ' ') {
        return _handleTriggerSpace(newValue.text, cursor) ?? newValue;
      }
    } else if (isDeletion) {
      return _handleBackspace(newValue.text, cursor) ?? newValue;
    }

    return newValue;
  }

  int _startOfLineEndingAt(String text, int end) {
    if (end <= 0) return 0;
    final idx = text.lastIndexOf('\n', end - 1);
    return idx == -1 ? 0 : idx + 1;
  }

  TextEditingValue? _handleEnter(String text, int cursor) {
    // cursor is AFTER the newly inserted \n
    final lineStart = _startOfLineEndingAt(text, cursor - 1);
    final closedLine = text.substring(lineStart, cursor - 1);

    final match = lineMarkerRegex.firstMatch(closedLine);
    if (match == null) return null;

    final indent = match.group(1)!;
    final marker = match.group(2)!;
    final content = closedLine.substring(match.end);

    // UX Improvement: If line is empty, outdent first, then exit the list.
    if (content.trim().isEmpty) {
      if (indent.length >= 2) {
        // Remove the \n we just added and outdent the current line
        final textWithoutNl = text.replaceRange(cursor - 1, cursor, '');
        final result = applyIndentShift(
          textWithoutNl,
          TextSelection.collapsed(offset: cursor - 1),
          outdent: true,
        );
        if (result != null) return result;
      }
      // Root level empty item: exit list by removing marker and newline.
      return TextEditingValue(
        text: text.replaceRange(lineStart, cursor, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // HRs don't continue to the next line.
    if (marker == hrMarker) return null;

    // Continue marker or increment number
    String nextMarker = marker;
    if (marker == checkboxDoneMarker) {
      // UX: Completed tasks usually continue as empty checkboxes
      nextMarker = checkboxEmptyMarker;
    } else {
      final numMatch = _numberedMarkerExact.firstMatch(marker);
      if (numMatch != null) {
        nextMarker = '${int.parse(numMatch.group(1)!) + 1}. ';
      }
    }

    final prefix = indent + nextMarker;
    return TextEditingValue(
      text: text.replaceRange(cursor, cursor, prefix),
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
  }

  TextEditingValue? _handleBackspace(String text, int cursor) {
    // Current cursor is AFTER the deletion.
    final lineStart = _startOfLineEndingAt(text, cursor);
    final nlIdx = text.indexOf('\n', lineStart);
    final lineEnd = nlIdx == -1 ? text.length : nlIdx;
    final line = text.substring(lineStart, lineEnd);

    // 1. Clear line if it's now just a marker with no content.
    final markerMatch = lineMarkerRegex.firstMatch(line);
    if (markerMatch != null && markerMatch.end == line.length) {
      return TextEditingValue(
        text: text.replaceRange(lineStart, lineEnd, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 2. Smart Deletion: If we just deleted the trailing space of a marker, delete the whole thing.
    // e.g. "• " -> backspace -> "•" -> clear it.
    final brokenMarkerMatch =
        RegExp(r'^( *)(•|◦|▪|☐|☑|>|───|\d{1,9}\.)$').firstMatch(line);
    if (brokenMarkerMatch != null && brokenMarkerMatch.end == line.length) {
      return TextEditingValue(
        text: text.replaceRange(lineStart, lineEnd, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    return null;
  }

  TextEditingValue? _handleTriggerSpace(String text, int cursor) {
    final lineStart = _startOfLineEndingAt(text, cursor - 1);
    final beforeSpace = text.substring(lineStart, cursor - 1);

    // Support markdown shortcuts and numbered list starts (e.g., "1.")
    final match = RegExp(
            r'^( *)(-|\*|\[\]|\[ \]|\[x\]|\[X\]|>|---|\*\*\*|___|\d{1,9}\.)$')
        .firstMatch(beforeSpace);
    if (match == null) return null;

    final indent = match.group(1)!;
    final token = match.group(2)!;

    String? replacement;
    if (token == '-' || token == '*') {
      replacement = bulletForDepth(indent.length ~/ 2);
    } else if (token == '[]' || token == '[ ]') {
      replacement = checkboxEmptyMarker;
    } else if (token == '[x]' || token == '[X]') {
      replacement = checkboxDoneMarker;
    } else if (token == '>') {
      replacement = blockquoteMarker;
    } else if (token == '---' || token == '***' || token == '___') {
      replacement = hrMarker;
    } else if (RegExp(r'^\d+\.$').hasMatch(token)) {
      replacement = '$token '; // Standardize spacing by adding the trailing space
    }

    if (replacement == null) return null;

    final newText = text.replaceRange(lineStart, cursor, indent + replacement);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lineStart + indent.length + replacement.length,
      ),
    );
  }

  /// Indents or outdents the list item at [selection] by one step (2 spaces).
  static TextEditingValue? applyIndentShift(
    String text,
    TextSelection selection, {
    required bool outdent,
  }) {
    if (!selection.isValid) return null;

    final offset = selection.start;
    final lineStart = offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    final nlIdx = text.indexOf('\n', lineStart);
    final lineEnd = nlIdx == -1 ? text.length : nlIdx;
    final line = text.substring(lineStart, lineEnd);

    final match = lineMarkerRegex.firstMatch(line);
    if (match == null) return null;

    final currentIndent = match.group(1)!.length;
    final marker = match.group(2)!;

    int newIndentLen;
    if (outdent) {
      if (currentIndent == 0) return null;
      newIndentLen = (currentIndent - 2).clamp(0, currentIndent);
    } else {
      if (currentIndent >= maxIndentSteps * 2) return null;
      newIndentLen = currentIndent + 2;
    }

    String newMarker = marker;
    if (isBulletMarker(marker)) {
      newMarker = bulletForDepth(newIndentLen ~/ 2);
    } else if (_numberedMarkerExact.hasMatch(marker) && !outdent) {
      // Standard markdown behavior: indenting a numbered list starts a new sequence.
      newMarker = '1. ';
    }

    final rest = line.substring(match.end);
    final newLine = '${' ' * newIndentLen}$newMarker$rest';

    final delta = newLine.length - line.length;
    return TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, newLine),
      selection: TextSelection.collapsed(
        offset: (offset + delta).clamp(lineStart, lineStart + newLine.length),
      ),
    );
  }
}
