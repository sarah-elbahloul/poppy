import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
// ─────────────────────────────────────────────────────────────
//  POPPY — App Icons
//  Location: lib/core/style/app_icons.dart
//
//  Single source of truth for every icon used in Poppy.
//  Using Iconsax for a clean, modern aesthetic.
//  All icons return IconData to ensure compatibility with
//  existing Icon() widgets.
// ─────────────────────────────────────────────────────────────

class AppIcons {
  AppIcons._();

  // ── Navigation & actions ───────────────────────────────
  static const IconData back       = Iconsax.arrow_left_2;
  static const IconData close      = Icons.close;
  static const IconData search     = Iconsax.search_normal_14;
  static const IconData settings   = Iconsax.setting_2;
  static const IconData selectAll   = Iconsax.task;
  static const IconData more       = Iconsax.more_circle;
  static const IconData sandwich       = Iconsax.menu_1;
  static const IconData check      = Icons.check;
  static const IconData checkCircle = Iconsax.tick_circle;
  static const IconData add        = Iconsax.add;
  static const IconData delete     = Iconsax.trash;
  static const IconData edit       = Iconsax.edit_2;
  static const IconData sort       = Iconsax.arrow_swap;
  static const IconData save       = Iconsax.tick_circle;
  static const IconData copy       = Iconsax.copy;
  static const IconData chevronRight = Iconsax.arrow_right_3;
  static const IconData chevronDown  = Iconsax.arrow_down_1;
  static const IconData chevronUp    = Iconsax.arrow_up_2;

  // ── Writing ────────────────────────────────────────────
  static const IconData write      = Iconsax.edit_2;
  static const IconData title      = Iconsax.text;
  static const IconData wordCount  = Iconsax.text_block;
  static const IconData tag        = Iconsax.tag;
  static const IconData color        = Iconsax.colorfilter;

  // ── Photos ─────────────────────────────────────────────
  static const IconData photo      = Iconsax.gallery;
  static const IconData photoAdd   = Iconsax.gallery_add;
  static const IconData gallery    = Iconsax.gallery;
  static const IconData camera     = Iconsax.camera;
  static const IconData imageBroken = Iconsax.gallery_slash;

  // ── Auth & account ─────────────────────────────────────
  static const IconData person     = Iconsax.user;
  static const IconData email      = Iconsax.sms;
  static const IconData emailUnread = Iconsax.notification_status;
  static const IconData password   = Iconsax.password_check;
  static const IconData logout     = Iconsax.logout;
  static const IconData visibilityOn  = Iconsax.eye;
  static const IconData visibilityOff = Iconsax.eye_slash;

  // ── Security ───────────────────────────────────────────
  static const IconData lock       = Iconsax.lock;
  static const IconData lockOpen   = Iconsax.unlock;
  static const IconData pin        = Iconsax.password_check;
  static const IconData backspace  = Iconsax.arrow_left;
  static const IconData fingerprint = Iconsax.finger_scan;

  // ── Settings sections ──────────────────────────────────
  static const IconData appearance = Iconsax.colorfilter;
  static const IconData security   = Iconsax.lock_1;
  static const IconData export_    = Iconsax.export;
  static const IconData import_    = Iconsax.import;
  static const IconData info       = Iconsax.info_circle;
  static const IconData warning    = Iconsax.warning_2;
  static const IconData privacyPolicy       = Iconsax.shield;
  static const IconData Tos       = Iconsax.document;
  static const IconData Osl       = Iconsax.info_circle;

  // ── Entry states ───────────────────────────────────────
  static const IconData emptyDiary = Iconsax.note;
  static const IconData offline    = Iconsax.cloud_remove;
  static const IconData retry      = Iconsax.refresh;

  // ── Date & time ────────────────────────────────────────
  static const IconData calendar   = Iconsax.calendar_1;
  static const IconData time       = Iconsax.clock;

  // ── Color tags ─────────────────────────────────────────
  static const IconData tagOutline = Iconsax.tag;
}