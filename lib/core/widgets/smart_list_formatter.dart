import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Smart List Formatter
//  Location: lib/core/widgets/smart_list_formatter.dart
// ─────────────────────────────────────────────────────────────

/// Auto-continues plain-text lists as you type, the way Notion, Apple
/// Notes, and most chat compose boxes do: write a line starting with
/// `- `, `* `, or `1. ` and pressing Enter carries the right marker
/// (the next bullet, or the next number) onto the new line for you.
/// Pressing Enter again on an empty list item clears that line's
/// marker and drops you out of the list, instead of continuing it
/// forever.
///
/// This only ever rearranges plain text — the markers ("- ", "2. ",
/// etc.) are ordinary characters in the saved entry, exactly like
/// typing them by hand. Nothing about how entries are stored changes.
class SmartListFormatter extends TextInputFormatter {
  static final _bullet = RegExp(r'^(\s*)([-*])\s(.*)$');
  static final _numbered = RegExp(r'^(\s*)(\d+)\.\s(.*)$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    final selection = newValue.selection;

    // Only handle a single Enter key-press: a collapsed cursor, exactly
    // one character longer than before, and that one new character is
    // a newline landing right at the cursor. Anything else (typing,
    // backspace, paste, autocorrect, programmatic edits) passes through
    // untouched.
    if (!selection.isCollapsed) return newValue;
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > newText.length) return newValue;
    if (newText.length != oldText.length + 1) return newValue;
    if (newText[cursor - 1] != '\n') return newValue;

    final lineStart = newText.lastIndexOf('\n', cursor - 2) + 1;
    final completedLine = newText.substring(lineStart, cursor - 1);

    final bulletMatch = _bullet.firstMatch(completedLine);
    final numberedMatch = _numbered.firstMatch(completedLine);
    final match = bulletMatch ?? numberedMatch;
    if (match == null) return newValue;

    final indent = match.group(1) ?? '';
    final content = match.group(3) ?? '';

    if (content.trim().isEmpty) {
      // Enter on an empty list item: drop the marker and exit the list,
      // leaving a single, ordinary blank line behind.
      final head = newText.substring(0, lineStart);
      final tail = newText.substring(cursor);
      return TextEditingValue(
        text: '$head\n$tail',
        selection: TextSelection.collapsed(offset: head.length + 1),
      );
    }

    final marker = numberedMatch != null
        ? '$indent${int.parse(numberedMatch.group(2)!) + 1}. '
        : '$indent${bulletMatch!.group(2)} ';

    final before = newText.substring(0, cursor);
    final after = newText.substring(cursor);
    return TextEditingValue(
      text: '$before$marker$after',
      selection: TextSelection.collapsed(offset: cursor + marker.length),
    );
  }
}