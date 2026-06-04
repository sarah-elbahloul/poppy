// ─────────────────────────────────────────────────────────────
//  POPPY — App-wide Constants
//  Location: lib/core/constants.dart
// ─────────────────────────────────────────────────────────────

const String kAppName    = 'Poppy';
const String kAppTagline = 'where every day finds its petal';

// ─────────────────────────────────────────────────────────────
//  SECURE STORAGE KEYS
// ─────────────────────────────────────────────────────────────

class StorageKeys {
  StorageKeys._();
  static const String pinHash          = 'poppy_pin_hash';
  static const String pinEnabled       = 'poppy_pin_enabled';
  static const String selectedTheme    = 'poppy_theme';
  static const String selectedTitleFont  = 'poppy_title_font';
  static const String selectedBodyFont   = 'poppy_body_font';
  static const String selectedFontSize   = 'poppy_font_size';
  static const String selectedLineHeight = 'poppy_line_height';
  // Per-slot colour overrides (absent = use Poppy default)
  static const String colorAccent        = 'poppy_color_accent';
  static const String colorAccentLight   = 'poppy_color_accent_light';
  static const String colorAccentMuted   = 'poppy_color_accent_muted';
  static const String colorSurface       = 'poppy_color_surface';
  static const String colorBackground    = 'poppy_color_background';
  static const String colorTextPrimary   = 'poppy_color_text_primary';
  static const String colorTextSecondary = 'poppy_color_text_secondary';
  static const String colorTextTertiary  = 'poppy_color_text_tertiary';
  static const String colorBorder        = 'poppy_color_border';
  // Cached plaintext data key bytes (base64).
  // Avoids a DB round-trip on every cold start.
  static const String dataKey          = 'poppy_data_key';
  // Temporary wrapped key blob stored between sign-up and first
  // sign-in (email confirmation means no session at sign-up time).
  // Cleared once successfully saved to user_keys table.
  static const String pendingEncKey    = 'poppy_pending_enc_key';
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
  static const String jsonVersion = '1.0';

  /// Generates a timestamped filename, e.g. poppy_2026-05-29_14-30.json
  /// Using .json so every platform/app can open it without registering
  /// a custom MIME type for .poppy.
  static String fileName() {
    final now = DateTime.now();
    final ts  = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'poppy_$ts.json';
  }
}
