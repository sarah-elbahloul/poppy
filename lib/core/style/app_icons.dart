import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Icon System
// ─────────────────────────────────────────────────────────────

/// Centralized repository for all icons used in the application.
///
/// Uses the Iconsax library for a consistent, modern aesthetic.
class AppIcons {
  AppIcons._();

  // ─── Navigation & Actions ───
  /// Back navigation icon.
  static const IconData back         = Iconsax.arrow_left_2;
  /// Close or cancel icon.
  static const IconData close        = Icons.close;
  /// Search action icon.
  static const IconData search       = Iconsax.search_normal_14;
  /// Settings or configuration icon.
  static const IconData settings     = Iconsax.setting_2;
  /// More options or overflow icon.
  static const IconData more         = Iconsax.more_circle;
  /// Hamburger menu or drawer icon.
  static const IconData sandwich     = Iconsax.menu_1;
  /// Simple checkmark icon.
  static const IconData check        = Icons.check;
  /// Checkmark inside a circle.
  static const IconData checkCircle  = Iconsax.tick_circle;
  /// Add or create icon.
  static const IconData add          = Iconsax.add;
  /// Delete or trash icon.
  static const IconData delete       = Iconsax.trash;
  /// Edit or pencil icon.
  static const IconData edit         = Iconsax.edit_2;
  /// Sort or swap icon.
  static const IconData sort      = Iconsax.arrow_swap;
  /// Sort ascending icon (oldest → newest).
  static const IconData sortAsc      = Iconsax.arrow_swap;
  /// Sort descending icon (newest → oldest).
  static const IconData sortDesc     = Iconsax.arrow_swap;
  /// Copy to clipboard icon.
  static const IconData copy         = Iconsax.copy;
  /// Right-pointing chevron icon.
  static const IconData chevronRight = Iconsax.arrow_right_3;
  /// Down-pointing chevron icon.
  static const IconData chevronDown  = Iconsax.arrow_down_1;
  /// Up-pointing chevron icon.
  static const IconData chevronUp    = Iconsax.arrow_up_2;

  // ─── Writing ───
  /// Write or compose icon.
  static const IconData write      = Iconsax.edit_2;
  /// Text or title icon.
  static const IconData title      = Iconsax.text;
  /// Word count or text block icon.
  static const IconData wordCount  = Iconsax.text_block;
  /// Tag or label icon.
  static const IconData tag        = Iconsax.tag;
  /// Color palette or theme icon.
  static const IconData color      = Iconsax.colorfilter;

  // ─── Photos ───
  /// Generic photo or gallery icon.
  static const IconData photo       = Iconsax.gallery;
  /// Icon for adding a photo to the gallery.
  static const IconData photoAdd    = Iconsax.gallery_add;
  /// Gallery view icon.
  static const IconData gallery     = Iconsax.gallery;
  /// Camera action icon.
  static const IconData camera      = Iconsax.camera;
  /// Icon for a broken or missing image.
  static const IconData imageBroken = Iconsax.gallery_slash;

  // ─── Auth & Account ───
  /// User or profile icon.
  static const IconData person        = Iconsax.user;
  /// Email or SMS icon.
  static const IconData email         = Iconsax.sms;
  /// Unread notification or message status icon.
  static const IconData emailUnread   = Iconsax.notification_status;
  /// Password or security key icon.
  static const IconData password      = Iconsax.password_check;
  /// Logout or sign-out icon.
  static const IconData logout        = Iconsax.logout;
  /// Visible password or eye icon.
  static const IconData visibilityOn  = Iconsax.eye;
  /// Hidden password or eye-slash icon.
  static const IconData visibilityOff = Iconsax.eye_slash;

  // ─── Security ───
  /// Locked or secure status icon.
  static const IconData lock        = Iconsax.lock;
  /// Unlocked status icon.
  static const IconData lockOpen    = Iconsax.unlock;
  /// PIN code or numeric password icon.
  static const IconData pin         = Iconsax.password_check;
  /// Backspace action for keypads.
  static const IconData backspace   = Iconsax.arrow_left;
  /// Biometric or fingerprint scan icon.
  static const IconData fingerprint = Iconsax.finger_scan;

  // ─── Settings Hub ───
  /// Appearance or styling settings icon.
  static const IconData appearance    = Iconsax.colorfilter;
  /// Privacy and security settings icon.
  static const IconData security      = Iconsax.lock_1;
  /// Data export icon.
  static const IconData export_       = Iconsax.export;
  /// Data import icon.
  static const IconData import_       = Iconsax.import;
  /// Information or about icon.
  static const IconData info          = Iconsax.info_circle;
  /// Warning or alert icon.
  static const IconData warning       = Iconsax.warning_2;
  /// Privacy policy icon.
  static const IconData privacyPolicy = Iconsax.shield;
  /// Terms of Service icon.
  static const IconData Tos           = Iconsax.document;
  /// Open Source Licenses icon.
  static const IconData Osl           = Iconsax.info_circle;

  // ─── States & Date ───
  /// Empty diary or placeholder icon.
  static const IconData emptyDiary = Iconsax.note;
  /// Offline or no connection icon.
  static const IconData offline    = Iconsax.cloud_remove;
  /// Refresh or retry action icon.
  static const IconData retry      = Iconsax.refresh;
  /// Calendar or date selection icon.
  static const IconData calendar   = Iconsax.calendar_1;
  /// Clock or time icon.
  static const IconData time       = Iconsax.clock;

  /// Outlined version of the tag icon.
  static const IconData tagOutline = Iconsax.tag;
}