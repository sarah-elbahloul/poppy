// ─────────────────────────────────────────────────────────────
//  POPPY — Global Constants
// ─────────────────────────────────────────────────────────────
//
// Unlike core/style, this file is NOT meant to be portable as-is — it's
// this app's specific branding, storage keys, and database schema. When
// starting a new project from this codebase, treat it as a template: keep
// the *shape* (grouped, private-constructor constant classes) and replace
// the values for your own app, tables, and columns.

/// Global naming and branding constants for the Poppy application.
class AppConstants {
  AppConstants._();

  /// The name of the application.
  static const String AppName = 'Poppy';

  /// The tagline for the application.
  static const String AppTagline = 'where every day finds its petal';
}

// ─────────────────────────────────────────────────────────────
//  Storage Keys
// ─────────────────────────────────────────────────────────────

/// Keys used for local secure storage (FlutterSecureStorage) and Shared Preferences.
class StorageKeys {
  StorageKeys._();

  // Security & Authentication
  /// Key for storing the hashed PIN.
  static const String pinHash = 'poppy_pin_hash';
  /// Key for whether PIN protection is enabled.
  static const String pinEnabled = 'poppy_pin_enabled';

  // Theme & Personalization
  /// Key for the selected theme name.
  static const String selectedTheme = 'poppy_theme';
  /// Key for the selected title font family.
  static const String selectedTitleFont = 'poppy_title_font';
  /// Key for the selected body font family.
  static const String selectedBodyFont = 'poppy_body_font';
  /// Key for the selected font size multiplier.
  static const String selectedFontSize = 'poppy_font_size';
  /// Key for the selected line height multiplier.
  static const String selectedLineHeight = 'poppy_line_height';
  /// Key for the selected border radius.
  static const String selectedBorderRadius = 'poppy_border_radius';

  // Per-slot color overrides (for custom theme tweaks)
  /// Key for the custom accent color.
  static const String colorAccent = 'poppy_color_accent';
  /// Key for the custom light accent color.
  static const String colorAccentLight = 'poppy_color_accent_light';
  /// Key for the custom muted accent color.
  static const String colorAccentMuted = 'poppy_color_accent_muted';
  /// Key for the custom surface color.
  static const String colorSurface = 'poppy_color_surface';
  /// Key for the custom background color.
  static const String colorBackground = 'poppy_color_background';
  /// Key for the custom primary text color.
  static const String colorTextPrimary = 'poppy_color_text_primary';
  /// Key for the custom secondary text color.
  static const String colorTextSecondary = 'poppy_color_text_secondary';
  /// Key for the custom tertiary text color.
  static const String colorTextTertiary = 'poppy_color_text_tertiary';
  /// Key for the custom border color.
  static const String colorBorder = 'poppy_color_border';

  // Encryption & Keys
  /// Cached plaintext data key bytes (base64 encoded).
  static const String dataKey = 'poppy_data_key';
  /// Temporary wrapped key blob stored during the sign-up flow.
  static const String pendingEncKey = 'poppy_pending_enc_key';

  // Metadata
  /// Cached entry tags JSON.
  static const String entryTags = 'poppy_entry_tags';
}

// ─────────────────────────────────────────────────────────────
//  Database Schema
// ─────────────────────────────────────────────────────────────

/// Supabase database table names.
class DBTable {
  DBTable._();

  /// The table for user profiles.
  static const String profiles = 'profiles';
  /// The table for journal entries.
  static const String entries = 'entries';
  /// The table for entry photos.
  static const String photos = 'photos';
  /// The table for user encryption keys.
  static const String userKeys = 'user_keys';
  /// The table for tracking local sync operations.
  static const String syncQueue = 'sync_queue';
}

/// Supabase database column names.
///
/// Used consistently across local SQLite and remote PostgreSQL schemas.
class DBColumn {
  DBColumn._();

  /// Unique identifier column.
  static const String id = 'id';
  /// User identifier column.
  static const String userId = 'user_id';
  /// Creation timestamp column.
  static const String createdAt = 'created_at';
  /// Last update timestamp column.
  static const String updatedAt = 'updated_at';
  /// Encrypted title column.
  static const String titleEnc = 'title_enc';
  /// Encrypted content column.
  static const String contentEnc = 'content_enc';
  /// Color tag identifier column.
  static const String colorTag = 'color_tag';
  /// Word count column.
  static const String wordCount = 'word_count';
  /// Date associated with the entry column.
  static const String entryDate = 'entry_date';
  /// Parent entry identifier column (for photos).
  static const String entryId = 'entry_id';
  /// Remote storage path column.
  static const String storagePath = 'storage_path';
  /// Display order index column.
  static const String orderIndex = 'order_index';

  // Theme Settings
  /// Title font family column.
  static const String fontTitle = 'font_title';
  /// Body font family column.
  static const String fontBody = 'font_body';
  /// Theme colors JSON column.
  static const String themeColors = 'theme_colors';

  /// PIN enabled status column.
  static const String pinEnabled = 'pin_enabled';
  /// User-defined tags JSON column.
  static const String tags = 'tags';

  // Sync related columns
  /// Local sync status column.
  static const String syncStatus = 'sync_status';
  /// Deletion flag column.
  static const String isDeleted = 'is_deleted';
  /// Local file path column.
  static const String localPath = 'local_path';
  /// Uploaded status flag column.
  static const String uploaded = 'uploaded';

  // Specific to the user_keys table.
  /// Encrypted data key column.
  static const String encDataKey = 'encrypted_data_key';
  /// Recovery encrypted data key column.
  static const String recoveryEncDataKey = 'recovery_enc_data_key';
}

// ─────────────────────────────────────────────────────────────
//  Cloud Storage
// ─────────────────────────────────────────────────────────────

/// Supabase storage bucket names.
class StorageBucket {
  StorageBucket._();

  /// Bucket for storing entry photos.
  static const String photos = 'entry-photos';
}

// ─────────────────────────────────────────────────────────────
//  Features & Exports
// ─────────────────────────────────────────────────────────────

/// Configuration for data export and import functionality.
class ExportConfig {
  ExportConfig._();

  /// The version of the export JSON format.
  static const String jsonVersion = '1.0';

  /// Generates a timestamped filename for diary exports (e.g., poppy_2025-01-28_14-30.json).
  static String fileName() {
    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'poppy_$ts.json';
  }
}