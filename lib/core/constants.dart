import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — App-wide Constants
//  Location: lib/core/constants.dart
// ─────────────────────────────────────────────────────────────

// ── App identity ─────────────────────────────────────────────

const String kAppName = 'Poppy';
const String kAppTagline = 'where every day finds its petal';

// ── Spacing scale ─────────────────────────────────────────────
// Use these instead of raw numbers so spacing is consistent
// across every screen.

const double kSpaceXS = 4.0;
const double kSpaceSM = 8.0;
const double kSpaceMD = 14.0;
const double kSpaceLG = 20.0;
const double kSpaceXL = 32.0;

// ── Border radius ─────────────────────────────────────────────

const double kRadiusSM = 8.0;
const double kRadiusMD = 12.0;
const double kRadiusLG = 16.0;
const double kRadiusXL = 24.0;

// ── Entry color tag strip width ───────────────────────────────
// The 3px left accent strip on every entry card.

const double kColorStripWidth = 3.0;

// ── Animation durations ───────────────────────────────────────

const Duration kAnimFast = Duration(milliseconds: 150);
const Duration kAnimNormal = Duration(milliseconds: 250);
const Duration kAnimSlow = Duration(milliseconds: 400);

// ─────────────────────────────────────────────────────────────
//  COLOR TAG SYSTEM
//  These are the 6 tag colors users can assign to entries.
//  They are intentionally independent of the app theme —
//  a Poppy-red tag looks the same whether the user picked
//  the Iris or Marigold theme.
// ─────────────────────────────────────────────────────────────

enum EntryColor {
  poppy,
  iris,
  lily,
  marigold,
  lavender,
  stone,
}

class EntryColorData {
  final EntryColor id;
  final String name;       // shown in the color picker
  final Color color;       // the strip color
  final String dbValue;    // what gets stored in Supabase

  const EntryColorData({
    required this.id,
    required this.name,
    required this.color,
    required this.dbValue,
  });
}

class EntryColors {
  EntryColors._();

  static const poppy = EntryColorData(
    id: EntryColor.poppy,
    name: 'Poppy',
    color: Color(0xFFC94040),
    dbValue: 'poppy',
  );

  static const iris = EntryColorData(
    id: EntryColor.iris,
    name: 'Iris',
    color: Color(0xFF5C7FC4),
    dbValue: 'iris',
  );

  static const lily = EntryColorData(
    id: EntryColor.lily,
    name: 'Lily',
    color: Color(0xFF4FAD74),
    dbValue: 'lily',
  );

  static const marigold = EntryColorData(
    id: EntryColor.marigold,
    name: 'Marigold',
    color: Color(0xFFB87030),
    dbValue: 'marigold',
  );

  static const lavender = EntryColorData(
    id: EntryColor.lavender,
    name: 'Lavender',
    color: Color(0xFF9050A8),
    dbValue: 'lavender',
  );

  static const stone = EntryColorData(
    id: EntryColor.stone,
    name: 'Stone',
    color: Color(0xFF888888),
    dbValue: 'stone',
  );

  /// All tags in display order
  static const all = [poppy, iris, lily, marigold, lavender, stone];

  /// Default tag for new entries
  static const defaultColor = stone;

  /// Convert a db string back to EntryColorData
  static EntryColorData fromDbValue(String value) {
    return all.firstWhere(
          (c) => c.dbValue == value,
      orElse: () => stone,
    );
  }

  /// Convert EntryColor enum to EntryColorData
  static EntryColorData fromId(EntryColor id) {
    return all.firstWhere((c) => c.id == id);
  }
}

// ─────────────────────────────────────────────────────────────
//  SECURE STORAGE KEYS
//  Keys used with flutter_secure_storage.
//  Centralised here so there are no magic strings scattered
//  across the codebase.
// ─────────────────────────────────────────────────────────────

class StorageKeys {
  StorageKeys._();

  static const String pinHash        = 'poppy_pin_hash';
  static const String pinEnabled     = 'poppy_pin_enabled';
  static const String selectedTheme  = 'poppy_theme';
  static const String supabaseSession = 'poppy_supabase_session';
}

// ─────────────────────────────────────────────────────────────
//  SUPABASE TABLE & COLUMN NAMES
//  Single source of truth — change a table name here and
//  it updates everywhere.
// ─────────────────────────────────────────────────────────────

class DBTable {
  DBTable._();

  static const String profiles = 'profiles';
  static const String entries  = 'entries';
  static const String photos   = 'photos';
}

class DBColumn {
  DBColumn._();

  // shared
  static const String id        = 'id';
  static const String userId    = 'user_id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  // entries
  static const String title     = 'title';
  static const String content   = 'content';
  static const String colorTag  = 'color_tag';
  static const String wordCount = 'word_count';

  // photos
  static const String entryId      = 'entry_id';
  static const String storagePath  = 'storage_path';
  static const String orderIndex   = 'order_index';

  // profiles
  static const String theme        = 'theme';
  static const String pinEnabled   = 'pin_enabled';
}

// ─────────────────────────────────────────────────────────────
//  SUPABASE STORAGE
// ─────────────────────────────────────────────────────────────

class StorageBucket {
  StorageBucket._();

  static const String photos = 'entry-photos';
}

// ─────────────────────────────────────────────────────────────
//  EXPORT / IMPORT
// ─────────────────────────────────────────────────────────────

class ExportConfig {
  ExportConfig._();

  static const String jsonFileName     = 'poppy_export.json';
  static const String jsonVersion      = '1.0';
}