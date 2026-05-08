import 'package:poppy/core/style/style.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — App-wide Constants
//  Location: lib/core/constants.dart
// ─────────────────────────────────────────────────────────────

const String kAppName    = 'Poppy';
const String kAppTagline = 'where every day finds its petal';

// ─────────────────────────────────────────────────────────────
//  ENTRY COLOR TAG SYSTEM
// ─────────────────────────────────────────────────────────────

enum EntryColor { poppy, iris, lily, marigold, lavender, stone }

class EntryColorData {
  final EntryColor id;
  final String     name;
  final dynamic    color; // Color — avoids importing flutter here
  final String     dbValue;

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
    id: EntryColor.poppy, name: 'Poppy',
    color: AppColors.tagPoppy, dbValue: 'poppy',
  );
  static const iris = EntryColorData(
    id: EntryColor.iris, name: 'Iris',
    color: AppColors.tagIris, dbValue: 'iris',
  );
  static const lily = EntryColorData(
    id: EntryColor.lily, name: 'Lily',
    color: AppColors.tagLily, dbValue: 'lily',
  );
  static const marigold = EntryColorData(
    id: EntryColor.marigold, name: 'Marigold',
    color: AppColors.tagMarigold, dbValue: 'marigold',
  );
  static const lavender = EntryColorData(
    id: EntryColor.lavender, name: 'Lavender',
    color: AppColors.tagLavender, dbValue: 'lavender',
  );
  static const stone = EntryColorData(
    id: EntryColor.stone, name: 'Stone',
    color: AppColors.tagStone, dbValue: 'stone',
  );

  static const all          = [poppy, iris, lily, marigold, lavender, stone];
  static const defaultColor = stone;

  static EntryColorData fromDbValue(String value) => all.firstWhere(
        (c) => c.dbValue == value, orElse: () => stone,
  );
  static EntryColorData fromId(EntryColor id) =>
      all.firstWhere((c) => c.id == id);
}

// ─────────────────────────────────────────────────────────────
//  SECURE STORAGE KEYS
// ─────────────────────────────────────────────────────────────

class StorageKeys {
  StorageKeys._();
  static const String pinHash         = 'poppy_pin_hash';
  static const String pinEnabled      = 'poppy_pin_enabled';
  static const String selectedTheme   = 'poppy_theme';
  static const String supabaseSession = 'poppy_supabase_session';
}

// ─────────────────────────────────────────────────────────────
//  DATABASE TABLE & COLUMN NAMES
// ─────────────────────────────────────────────────────────────

class DBTable {
  DBTable._();
  static const String profiles = 'profiles';
  static const String entries  = 'entries';
  static const String photos   = 'photos';
}

class DBColumn {
  DBColumn._();
  static const String id           = 'id';
  static const String userId       = 'user_id';
  static const String createdAt    = 'created_at';
  static const String updatedAt    = 'updated_at';
  static const String title        = 'title';
  static const String content      = 'content';
  static const String colorTag     = 'color_tag';
  static const String wordCount    = 'word_count';
  static const String entryDate    = 'entry_date';
  static const String entryId      = 'entry_id';
  static const String storagePath  = 'storage_path';
  static const String orderIndex   = 'order_index';
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
  static const String jsonVersion  = '1.0';
  static const String jsonFileName = 'poppy_export.json';   // legacy
  static const String poppyFileName = 'poppy_export.poppy'; // new format
}