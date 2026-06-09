/// Global constants for the Poppy application.
class AppConstants {
  AppConstants._();

  static const String AppName = 'Poppy';
  static const String AppTagline = 'where every day finds its petal';
}

/// Keys used for local secure storage and shared preferences.
class StorageKeys {
  StorageKeys._();

  static const String pinHash = 'poppy_pin_hash';
  static const String pinEnabled = 'poppy_pin_enabled';
  static const String selectedTheme = 'poppy_theme';
  static const String selectedTitleFont = 'poppy_title_font';
  static const String selectedBodyFont = 'poppy_body_font';
  static const String selectedFontSize = 'poppy_font_size';
  static const String selectedLineHeight = 'poppy_line_height';

  // Per-slot color overrides.
  static const String colorAccent = 'poppy_color_accent';
  static const String colorAccentLight = 'poppy_color_accent_light';
  static const String colorAccentMuted = 'poppy_color_accent_muted';
  static const String colorSurface = 'poppy_color_surface';
  static const String colorBackground = 'poppy_color_background';
  static const String colorTextPrimary = 'poppy_color_text_primary';
  static const String colorTextSecondary = 'poppy_color_text_secondary';
  static const String colorTextTertiary = 'poppy_color_text_tertiary';
  static const String colorBorder = 'poppy_color_border';

  /// Cached plaintext data key bytes (base64 encoded).
  static const String dataKey = 'poppy_data_key';

  /// Temporary wrapped key blob stored during the sign-up flow.
  static const String pendingEncKey = 'poppy_pending_enc_key';
}

/// Supabase database table names.
class DBTable {
  DBTable._();

  static const String profiles = 'profiles';
  static const String entries = 'entries';
  static const String photos = 'photos';
  static const String userKeys = 'user_keys';
  static const String syncQueue = 'sync_queue';
}

/// Supabase database column names.
class DBColumn {
  DBColumn._();

  static const String id = 'id';
  static const String userId = 'user_id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String titleEnc = 'title_enc';
  static const String contentEnc = 'content_enc';
  static const String colorTag = 'color_tag';
  static const String wordCount = 'word_count';
  static const String entryDate = 'entry_date';
  static const String entryId = 'entry_id';
  static const String storagePath = 'storage_path';
  static const String orderIndex = 'order_index';
  static const String theme = 'theme';
  static const String pinEnabled = 'pin_enabled';

  // Sync related columns
  static const String syncStatus = 'sync_status';
  static const String isDeleted = 'is_deleted';
  static const String localPath = 'local_path';
  static const String uploaded = 'uploaded';

  // Specific to the user_keys table.
  static const String encDataKey = 'encrypted_data_key';
  static const String recoveryEncDataKey = 'recovery_enc_data_key';
}

/// Supabase storage bucket names.
class StorageBucket {
  StorageBucket._();

  static const String photos = 'entry-photos';
}

/// Configuration for data export and import functionality.
class ExportConfig {
  ExportConfig._();

  static const String jsonVersion = '1.0';

  /// Generates a timestamped filename for diary exports.
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
