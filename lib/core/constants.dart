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
  final dynamic    color;
  final String     dbValue;
  const EntryColorData({
    required this.id, required this.name,
    required this.color, required this.dbValue,
  });
}

class EntryColors {
  EntryColors._();
  static const poppy    = EntryColorData(id: EntryColor.poppy,    name: 'Poppy',    color: AppColors.tagPoppy,    dbValue: 'poppy');
  static const iris     = EntryColorData(id: EntryColor.iris,     name: 'Iris',     color: AppColors.tagIris,     dbValue: 'iris');
  static const lily     = EntryColorData(id: EntryColor.lily,     name: 'Lily',     color: AppColors.tagLily,     dbValue: 'lily');
  static const marigold = EntryColorData(id: EntryColor.marigold, name: 'Marigold', color: AppColors.tagMarigold, dbValue: 'marigold');
  static const lavender = EntryColorData(id: EntryColor.lavender, name: 'Lavender', color: AppColors.tagLavender, dbValue: 'lavender');
  static const stone    = EntryColorData(id: EntryColor.stone,    name: 'Stone',    color: AppColors.tagStone,    dbValue: 'stone');

  static const all          = [poppy, iris, lily, marigold, lavender, stone];
  static const defaultColor = stone;

  static EntryColorData fromDbValue(String value) =>
      all.firstWhere((c) => c.dbValue == value, orElse: () => stone);
  static EntryColorData fromId(EntryColor id) =>
      all.firstWhere((c) => c.id == id);
}

// ─────────────────────────────────────────────────────────────
//  SECURE STORAGE KEYS
// ─────────────────────────────────────────────────────────────

class StorageKeys {
  StorageKeys._();
  static const String pinHash       = 'poppy_pin_hash';
  static const String pinEnabled    = 'poppy_pin_enabled';
  static const String selectedTheme = 'poppy_theme';
  // Cached plaintext data key bytes (base64).
  // Avoids a DB round-trip on every cold start.
  static const String dataKey       = 'poppy_data_key';
  // Temporary wrapped key blob stored between sign-up and first
  // sign-in (email confirmation means no session at sign-up time).
  // Cleared once successfully saved to user_keys table.
  static const String pendingEncKey = 'poppy_pending_enc_key';
}

// ─────────────────────────────────────────────────────────────
//  DATABASE TABLE & COLUMN NAMES
// ─────────────────────────────────────────────────────────────

class DBTable {
  DBTable._();
  static const String profiles = 'profiles';
  static const String entries  = 'entries';
  static const String photos   = 'photos';
  static const String userKeys = 'user_keys';
}

class DBColumn {
  DBColumn._();
  static const String id          = 'id';
  static const String userId      = 'user_id';
  static const String createdAt   = 'created_at';
  static const String updatedAt   = 'updated_at';
  static const String titleEnc    = 'title_enc';
  static const String contentEnc  = 'content_enc';
  static const String colorTag    = 'color_tag';
  static const String wordCount   = 'word_count';
  static const String entryDate   = 'entry_date';
  static const String entryId     = 'entry_id';
  static const String storagePath = 'storage_path';
  static const String orderIndex  = 'order_index';
  static const String theme       = 'theme';
  static const String pinEnabled  = 'pin_enabled';
  // user_keys table
  static const String encDataKey          = 'encrypted_data_key';
  static const String recoveryEncDataKey  = 'recovery_enc_data_key';
}

// ─────────────────────────────────────────────────────────────
//  SUPABASE STORAGE
// ─────────────────────────────────────────────────────────────

class StorageBucket {
  StorageBucket._();
  // saved in the way: bucket/userid/entryid/photo
  static const String photos = 'entry-photos';
}

// ─────────────────────────────────────────────────────────────
//  EXPORT / IMPORT
// ─────────────────────────────────────────────────────────────

class ExportConfig {
  ExportConfig._();
  static const String jsonVersion   = '1.0';
  static const String poppyFileName = 'poppy_export.poppy';
}