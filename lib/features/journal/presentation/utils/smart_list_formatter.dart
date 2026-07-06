import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Smart List Formatter
// ─────────────────────────────────────────────────────────────

/// Adds lightweight, chat-app-style typing shortcuts to a plain text
/// editor, without turning it into a full rich-text/markdown editor.
///
/// Supported shortcuts (each triggers the moment you type the trailing
/// space, exactly like WhatsApp's "type a dash + space to start a list"):
///
///   `- ` or `* `           → bullet point (`•`)
///   `1. `, `2. `, ...       → numbered list (auto-increments on Enter)
///   `[] ` / `[ ] `          → empty checkbox (`☐`)
///   `[x] ` / `[X] `         → checked checkbox (`☑`)
///
/// Once inside a list, pressing Enter continues the same marker onto the
/// next line (and bumps the number for numbered lists). Pressing Enter on
/// an empty list item removes the marker instead of adding another one,
/// so the list "ends" the same way it does in WhatsApp/Notes/Notion.
///
/// This is intentionally a pure [TextInputFormatter] — no extra toolbar,
/// buttons, or rich-text rendering — so it doesn't add any visual clutter
/// to the writing screen. The markers are plain unicode characters typed
/// straight into the text, so they save, sync, and search exactly like
/// the rest of the entry.
class SmartListFormatter extends TextInputFormatter {
  static const String bulletMarker = '• ';
  static const String checkboxEmptyMarker = '☐ ';
  static const String checkboxDoneMarker = '☑ ';

  static final RegExp _numberedMarker = RegExp(r'^(\d{1,3})\. ');
  static final RegExp _numberedMarkerExact = RegExp(r'^(\d{1,3})\. $');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Only handle simple typing (one new character at the cursor). Pastes,
    // autocorrect replacements, selection edits, and IME composing are all
    // left completely untouched so we never fight the user's input.
    final selection = newValue.selection;
    if (!selection.isValid || !selection.isCollapsed) return newValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final oldText = oldValue.text;
    final newText = newValue.text;
    final cursor = selection.baseOffset;

    final isSingleCharInsertion =
        newText.length == oldText.length + 1 && cursor > 0 && cursor <= newText.length;
    if (!isSingleCharInsertion) return newValue;

    final insertedChar = newText[cursor - 1];

    if (insertedChar == '\n') {
      return _handleEnter(newText, cursor) ?? newValue;
    }
    if (insertedChar == ' ') {
      return _handleTriggerSpace(newText, cursor) ?? newValue;
    }
    return newValue;
  }

  /// Finds the index where the line ending at (but not including) [end]
  /// begins.
  int _startOfLineEndingAt(String text, int end) {
    if (end <= 0) return 0;
    final idx = text.lastIndexOf('\n', end - 1);
    return idx == -1 ? 0 : idx + 1;
  }

  String? _markerOf(String line) {
    if (line.startsWith(bulletMarker)) return bulletMarker;
    if (line.startsWith(checkboxEmptyMarker)) return checkboxEmptyMarker;
    if (line.startsWith(checkboxDoneMarker)) return checkboxDoneMarker;
    final match = _numberedMarker.firstMatch(line);
    if (match != null) return match.group(0);
    return null;
  }

  String _nextMarker(String marker) {
    final match = _numberedMarkerExact.firstMatch(marker);
    if (match == null) return marker; // bullets & checkboxes repeat as-is
    final next = int.parse(match.group(1)!) + 1;
    return '$next. ';
  }

  TextEditingValue? _handleEnter(String text, int cursor) {
    // The newline was just inserted at index (cursor - 1). The line that
    // was "closed" by pressing Enter runs from its start up to there.
    final lineStart = _startOfLineEndingAt(text, cursor - 1);
    final closedLine = text.substring(lineStart, cursor - 1);

    final marker = _markerOf(closedLine);
    if (marker == null) return null;

    final content = closedLine.substring(marker.length);
    if (content.trim().isEmpty) {
      // Empty list item + Enter → exit the list: drop the marker and the
      // newline instead of starting another empty bullet.
      final newText = text.replaceRange(lineStart, cursor, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    final nextMarker = _nextMarker(marker);
    final newText = text.replaceRange(cursor, cursor, nextMarker);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + nextMarker.length),
    );
  }

  TextEditingValue? _handleTriggerSpace(String text, int cursor) {
    // `cursor` sits right after the space that was just typed.
    final lineStart = _startOfLineEndingAt(text, cursor - 1);
    final beforeSpace = text.substring(lineStart, cursor - 1);

    String? replacement;
    switch (beforeSpace) {
      case '-':
      case '*':
        replacement = bulletMarker;
        break;
      case '[]':
      case '[ ]':
        replacement = checkboxEmptyMarker;
        break;
      case '[x]':
      case '[X]':
        replacement = checkboxDoneMarker;
        break;
    }

    // Numbered lists (`1. `, `2. `, ...) are already valid plain text as
    // typed — nothing to substitute, they just get recognised on Enter.
    if (replacement == null) return null;

    final newText = text.replaceRange(lineStart, cursor, replacement);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + replacement.length),
    );
  }
}