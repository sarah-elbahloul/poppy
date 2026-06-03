import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/app_colors.dart';
import 'package:poppy/core/style/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Appearance Provider  (v4)
//  Location: lib/providers/theme_provider.dart
//
//  Colour system
//  ─────────────
//  There are no longer named preset themes.  The user owns every
//  one of the 9 colour slots individually:
//
//    accent       — buttons, FAB, selected states, icons
//    accentLight  — tinted backgrounds (entry card header, chips)
//    accentMuted  — muted accent (tag pills, secondary icons)
//    surface      — card backgrounds, input fields
//    background   — main scaffold background
//    textPrimary  — headings, body text
//    textSecondary— subtitles, labels
//    textTertiary — placeholders, hints, timestamps
//    border       — dividers, card outlines, input borders
//
//  Each slot persists as a hex string.  If a slot has never been
//  set (or the user taps "Reset"), the Poppy defaults below are used.
//
//  Font + sizing system
//  ────────────────────
//    titleFont   — font used for headings / app bar / entry titles
//    bodyFont    — font used for diary writing
//    fontSize    — S / M / L scale factor on body + title sizes
//    lineHeight  — tight / normal / airy for diary body
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
//  Defaults — the original Poppy palette
// ─────────────────────────────────────────────────────────────

class PoppyDefaults {
  PoppyDefaults._();

  static const accent        = Color(0xFFC94040);
  static const accentLight   = Color(0xFFFBEAEA);
  static const accentMuted   = Color(0xFFE8A0A0);
  static const surface       = Color(0xFFFDF8F8);
  static const background    = Color(0xFFFFFBFB);
  static const textPrimary   = Color(0xFF1A1212);
  static const textSecondary = Color(0xFF5C4444);
  static const textTertiary  = Color(0xFFAA8888);
  static const border        = Color(0xFFEDD8D8);
}

// ─────────────────────────────────────────────────────────────
//  Color slot descriptor
// ─────────────────────────────────────────────────────────────

class ColorSlot {
  final String key;
  final String label;
  final String description;
  final Color  defaultValue;

  const ColorSlot({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
  });
}

class ColorSlots {
  ColorSlots._();

  static const accent = ColorSlot(
    key:          StorageKeys.colorAccent,
    label:        'Accent',
    description:  'Buttons, FAB, selected icons',
    defaultValue: PoppyDefaults.accent,
  );
  static const accentLight = ColorSlot(
    key:          StorageKeys.colorAccentLight,
    label:        'Highlight',
    description:  'Card headers, tag backgrounds',
    defaultValue: PoppyDefaults.accentLight,
  );
  static const accentMuted = ColorSlot(
    key:          StorageKeys.colorAccentMuted,
    label:        'Muted',
    description:  'Secondary icons, pill chips',
    defaultValue: PoppyDefaults.accentMuted,
  );
  static const surface = ColorSlot(
    key:          StorageKeys.colorSurface,
    label:        'Surface',
    description:  'Cards, input field backgrounds',
    defaultValue: PoppyDefaults.surface,
  );
  static const background = ColorSlot(
    key:          StorageKeys.colorBackground,
    label:        'Background',
    description:  'Main screen background',
    defaultValue: PoppyDefaults.background,
  );
  static const textPrimary = ColorSlot(
    key:          StorageKeys.colorTextPrimary,
    label:        'Text',
    description:  'Headings and body text',
    defaultValue: PoppyDefaults.textPrimary,
  );
  static const textSecondary = ColorSlot(
    key:          StorageKeys.colorTextSecondary,
    label:        'Subtext',
    description:  'Labels, subtitles',
    defaultValue: PoppyDefaults.textSecondary,
  );
  static const textTertiary = ColorSlot(
    key:          StorageKeys.colorTextTertiary,
    label:        'Hint',
    description:  'Placeholders, timestamps',
    defaultValue: PoppyDefaults.textTertiary,
  );
  static const border = ColorSlot(
    key:          StorageKeys.colorBorder,
    label:        'Border',
    description:  'Card outlines, dividers',
    defaultValue: PoppyDefaults.border,
  );

  static const all = [
    accent, accentLight, accentMuted,
    surface, background,
    textPrimary, textSecondary, textTertiary,
    border,
  ];
}

// ─────────────────────────────────────────────────────────────
//  Font catalogue
// ─────────────────────────────────────────────────────────────

enum PoppyFont {
  // Classic
  lora, merriweather, crimsonPro, sourceSerif, libreBaskerville,
  // Expressive
  playfair, cormorant, literata, youngSerif, dmSerif, fraunces, bodoniModa,
  // Handwritten
  caveat, kalam, shadowsIntoLight, sacramento, patrickHand, indieFlower,
  // Friendly
  comfortaa, quicksand, nunito, fredoka, poppins,
  // Minimalist
  inter, outfit, spaceGrotesk, manrope, onest,
}

class PoppyFontData {
  final PoppyFont id;
  final String    displayName;
  final String    category;
  final String    tagline;

  const PoppyFontData({
    required this.id,
    required this.displayName,
    required this.category,
    required this.tagline,
  });

  TextStyle style(Color color, {double size = 16, double height = 1.8,
    FontWeight weight = FontWeight.w400}) {
    switch (id) {
    // Classic
      case PoppyFont.lora:             return GoogleFonts.lora(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.merriweather:     return GoogleFonts.merriweather(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.crimsonPro:       return GoogleFonts.crimsonPro(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.sourceSerif:      return GoogleFonts.sourceSerif4(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.libreBaskerville: return GoogleFonts.libreBaskerville(fontSize: size, color: color, height: height, fontWeight: weight);
    // Expressive
      case PoppyFont.playfair:   return GoogleFonts.playfairDisplay(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.cormorant:  return GoogleFonts.cormorantGaramond(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.literata:   return GoogleFonts.literata(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.youngSerif: return GoogleFonts.youngSerif(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.dmSerif:    return GoogleFonts.dmSerifDisplay(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.fraunces:   return GoogleFonts.fraunces(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.bodoniModa: return GoogleFonts.bodoniModa(fontSize: size, color: color, height: height, fontWeight: weight);
    // Handwritten
      case PoppyFont.caveat:           return GoogleFonts.caveat(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.kalam:            return GoogleFonts.kalam(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.shadowsIntoLight: return GoogleFonts.shadowsIntoLight(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.sacramento:       return GoogleFonts.sacramento(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.patrickHand:      return GoogleFonts.patrickHand(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.indieFlower:      return GoogleFonts.indieFlower(fontSize: size, color: color, height: height, fontWeight: weight);
    // Friendly
      case PoppyFont.comfortaa: return GoogleFonts.comfortaa(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.quicksand: return GoogleFonts.quicksand(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.nunito:    return GoogleFonts.nunito(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.fredoka:   return GoogleFonts.fredoka(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.poppins:   return GoogleFonts.poppins(fontSize: size, color: color, height: height, fontWeight: weight);
    // Minimalist
      case PoppyFont.inter:        return GoogleFonts.inter(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.outfit:       return GoogleFonts.outfit(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.spaceGrotesk: return GoogleFonts.spaceGrotesk(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.manrope:      return GoogleFonts.manrope(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.onest:        return GoogleFonts.onest(fontSize: size, color: color, height: height, fontWeight: weight);
    }
  }

  TextStyle bold(Color color, {double size = 16, double height = 1.3}) =>
      style(color, size: size, height: height, weight: FontWeight.w600);
}

class PoppyFonts {
  PoppyFonts._();

  // ── Classic ──────────────────────────────────────────────
  static const lora = PoppyFontData(
    id: PoppyFont.lora,
    displayName: 'Lora',
    category: 'Classic',
    tagline: 'Warm like a letter',
  );
  static const merriweather = PoppyFontData(
    id: PoppyFont.merriweather,
    displayName: 'Merriweather',
    category: 'Classic',
    tagline: 'Your trusty companion',
  );
  static const crimsonPro = PoppyFontData(
    id: PoppyFont.crimsonPro,
    displayName: 'Crimson Pro',
    category: 'Classic',
    tagline: 'Old bookshop energy',
  );
  static const sourceSerif = PoppyFontData(
    id: PoppyFont.sourceSerif,
    displayName: 'Source Serif',
    category: 'Classic',
    tagline: 'Editorial elegance',
  );
  static const libreBaskerville = PoppyFontData(
    id: PoppyFont.libreBaskerville,
    displayName: 'Libre Baskerville',
    category: 'Classic',
    tagline: 'Timeless & grounding',
  );

  // ── Expressive ───────────────────────────────────────────
  static const playfair = PoppyFontData(
    id: PoppyFont.playfair,
    displayName: 'Playfair',
    category: 'Expressive',
    tagline: 'Dramatic entrances',
  );
  static const cormorant = PoppyFontData(
    id: PoppyFont.cormorant,
    displayName: 'Cormorant',
    category: 'Expressive',
    tagline: 'Romantic poetry',
  );
  static const literata = PoppyFontData(
    id: PoppyFont.literata,
    displayName: 'Literata',
    category: 'Expressive',
    tagline: 'Cozy reading nook',
  );
  static const youngSerif = PoppyFontData(
    id: PoppyFont.youngSerif,
    displayName: 'Young Serif',
    category: 'Expressive',
    tagline: 'A little rebellious',
  );
  static const dmSerif = PoppyFontData(
    id: PoppyFont.dmSerif,
    displayName: 'DM Serif',
    category: 'Expressive',
    tagline: 'Quiet confidence',
  );
  static const fraunces = PoppyFontData(
    id: PoppyFont.fraunces,
    displayName: 'Fraunces',
    category: 'Expressive',
    tagline: 'Delightfully weird',
  );
  static const bodoniModa = PoppyFontData(
    id: PoppyFont.bodoniModa,
    displayName: 'Bodoni Moda',
    category: 'Expressive',
    tagline: 'Black-tie affair',
  );

  // ── Handwritten ──────────────────────────────────────────
  static const caveat = PoppyFontData(
    id: PoppyFont.caveat,
    displayName: 'Caveat',
    category: 'Handwritten',
    tagline: 'Quick thoughts',
  );
  static const kalam = PoppyFontData(
    id: PoppyFont.kalam,
    displayName: 'Kalam',
    category: 'Handwritten',
    tagline: 'Ink on paper',
  );
  static const shadowsIntoLight = PoppyFontData(
    id: PoppyFont.shadowsIntoLight,
    displayName: 'Shadows Into Light',
    category: 'Handwritten',
    tagline: 'Dreamy & light',
  );
  static const sacramento = PoppyFontData(
    id: PoppyFont.sacramento,
    displayName: 'Sacramento',
    category: 'Handwritten',
    tagline: 'Whispered secrets',
  );
  static const patrickHand = PoppyFontData(
    id: PoppyFont.patrickHand,
    displayName: 'Patrick Hand',
    category: 'Handwritten',
    tagline: 'Ruled notebook',
  );
  static const indieFlower = PoppyFontData(
    id: PoppyFont.indieFlower,
    displayName: 'Indie Flower',
    category: 'Handwritten',
    tagline: 'Wild & free',
  );

  // ── Friendly ─────────────────────────────────────────────
  static const comfortaa = PoppyFontData(
    id: PoppyFont.comfortaa,
    displayName: 'Comfortaa',
    category: 'Friendly',
    tagline: 'Soft & cozy',
  );
  static const quicksand = PoppyFontData(
    id: PoppyFont.quicksand,
    displayName: 'Quicksand',
    category: 'Friendly',
    tagline: 'Gentle breeze',
  );
  static const nunito = PoppyFontData(
    id: PoppyFont.nunito,
    displayName: 'Nunito',
    category: 'Friendly',
    tagline: 'Warm hug',
  );
  static const fredoka = PoppyFontData(
    id: PoppyFont.fredoka,
    displayName: 'Fredoka',
    category: 'Friendly',
    tagline: 'Pure joy',
  );
  static const poppins = PoppyFontData(
    id: PoppyFont.poppins,
    displayName: 'Poppins',
    category: 'Friendly',
    tagline: 'Approachable chic',
  );

  // ── Minimalist ───────────────────────────────────────────
  static const inter = PoppyFontData(
    id: PoppyFont.inter,
    displayName: 'Inter',
    category: 'Minimalist',
    tagline: 'Crystal clear',
  );
  static const outfit = PoppyFontData(
    id: PoppyFont.outfit,
    displayName: 'Outfit',
    category: 'Minimalist',
    tagline: 'Effortless cool',
  );
  static const spaceGrotesk = PoppyFontData(
    id: PoppyFont.spaceGrotesk,
    displayName: 'Space Grotesk',
    category: 'Minimalist',
    tagline: 'Future diary',
  );
  static const manrope = PoppyFontData(
    id: PoppyFont.manrope,
    displayName: 'Manrope',
    category: 'Minimalist',
    tagline: 'Quiet luxury',
  );
  static const onest = PoppyFontData(
    id: PoppyFont.onest,
    displayName: 'Onest',
    category: 'Minimalist',
    tagline: 'Friendly modern',
  );

  static const all = [
    // Classic
    lora, merriweather, crimsonPro, sourceSerif, libreBaskerville,
    // Expressive
    playfair, cormorant, literata, youngSerif, dmSerif, fraunces, bodoniModa,
    // Handwritten
    caveat, kalam, shadowsIntoLight, sacramento, patrickHand, indieFlower,
    // Friendly
    comfortaa, quicksand, nunito, fredoka, poppins,
    // Minimalist
    inter, outfit, spaceGrotesk, manrope, onest,
  ];

  static const categories = [
    'Classic',
    'Expressive',
    'Handwritten',
    'Friendly',
    'Minimalist',
  ];

  static List<PoppyFontData> byCategory(String category) =>
      all.where((f) => f.category == category).toList();

  static PoppyFontData fromId(PoppyFont id) =>
      all.firstWhere((f) => f.id == id, orElse: () => lora);
}

// ─────────────────────────────────────────────────────────────
//  Font size
// ─────────────────────────────────────────────────────────────

enum PoppyFontSize { small, medium, large }
extension PoppyFontSizeX on PoppyFontSize {
  String get label { switch (this) { case PoppyFontSize.small: return 'S'; case PoppyFontSize.medium: return 'M'; case PoppyFontSize.large: return 'L'; } }
  double get scale { switch (this) { case PoppyFontSize.small: return 0.875; case PoppyFontSize.medium: return 1.0; case PoppyFontSize.large: return 1.1875; } }
}

// ─────────────────────────────────────────────────────────────
//  Line height
// ─────────────────────────────────────────────────────────────

enum PoppyLineHeight { compact, normal, relaxed }
extension PoppyLineHeightX on PoppyLineHeight {
  String get label { switch (this) { case PoppyLineHeight.compact: return 'Tight'; case PoppyLineHeight.normal: return 'Normal'; case PoppyLineHeight.relaxed: return 'Airy'; } }
  double get value { switch (this) { case PoppyLineHeight.compact: return 1.5; case PoppyLineHeight.normal: return 1.8; case PoppyLineHeight.relaxed: return 2.2; } }
}

// ─────────────────────────────────────────────────────────────
//  FontPairData — thin wrapper for AppTextStyles call sites
// ─────────────────────────────────────────────────────────────

class FontPairData {
  final PoppyFontData _titleFont;
  final PoppyFontData _bodyFont;
  const FontPairData(this._titleFont, this._bodyFont);

  PoppyFontData get titleFont => _titleFont;
  PoppyFontData get bodyFont  => _bodyFont;

  TextStyle serifStyle(Color c, {double size = 16, double height = 1.8}) => _bodyFont.style(c, size: size, height: height);
  TextStyle serifBold (Color c, {double size = 16, double height = 1.3}) => _titleFont.bold(c, size: size, height: height);
  TextStyle sansStyle (Color c, {double size = 14, double height = 1.4}) => _bodyFont.style(c, size: size, height: height);
  TextStyle sansBold  (Color c, {double size = 14, double height = 1.4}) => _titleFont.bold(c, size: size, height: height);
}

// ─────────────────────────────────────────────────────────────
//  Hex helpers
// ─────────────────────────────────────────────────────────────

String _colorToHex(Color c) =>
    '#${(c.value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

Color _hexToColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  // Color overrides — null means "use default"
  final Map<String, Color> _colors = {};

  PoppyFont       _titleFont  = PoppyFont.lora;
  PoppyFont       _bodyFont   = PoppyFont.lora;
  PoppyFontSize   _fontSize   = PoppyFontSize.medium;
  PoppyLineHeight _lineHeight = PoppyLineHeight.normal;

  // ── Getters ──────────────────────────────────────────────

  Color colorFor(ColorSlot slot) =>
      _colors[slot.key] ?? slot.defaultValue;

  bool isCustomized(ColorSlot slot) => _colors.containsKey(slot.key);
  bool get hasAnyCustomColor => ColorSlots.all.any(isCustomized);

  PoppyFont       get currentTitleFont  => _titleFont;
  PoppyFont       get currentBodyFont   => _bodyFont;
  PoppyFontSize   get currentFontSize   => _fontSize;
  PoppyLineHeight get currentLineHeight => _lineHeight;

  FontPairData get currentFontPairData =>
      FontPairData(PoppyFonts.fromId(_titleFont), PoppyFonts.fromId(_bodyFont));

  /// Live PoppyThemeData built from current color slots
  PoppyThemeData get currentThemeData => PoppyThemeData(
    id:            PoppyTheme.poppy,
    name:          'Poppy',
    accent:        colorFor(ColorSlots.accent),
    accentLight:   colorFor(ColorSlots.accentLight),
    accentMuted:   colorFor(ColorSlots.accentMuted),
    surface:       colorFor(ColorSlots.surface),
    background:    colorFor(ColorSlots.background),
    textPrimary:   colorFor(ColorSlots.textPrimary),
    textSecondary: colorFor(ColorSlots.textSecondary),
    textTertiary:  colorFor(ColorSlots.textTertiary),
    border:        colorFor(ColorSlots.border),
  );

  ThemeProvider() { _loadAll(); }

  Future<void> _loadAll() async {
    try {
      // Colors
      for (final slot in ColorSlots.all) {
        final hex = await _storage.read(key: slot.key);
        if (hex != null) _colors[slot.key] = _hexToColor(hex);
      }
      // Fonts
      final tf = await _storage.read(key: StorageKeys.selectedTitleFont);
      final bf = await _storage.read(key: StorageKeys.selectedBodyFont);
      final fs = await _storage.read(key: StorageKeys.selectedFontSize);
      final lh = await _storage.read(key: StorageKeys.selectedLineHeight);

      _titleFont  = PoppyFont.values.firstWhere((f) => f.name == tf,  orElse: () => PoppyFont.lora);
      _bodyFont   = PoppyFont.values.firstWhere((f) => f.name == bf,  orElse: () => PoppyFont.lora);
      _fontSize   = PoppyFontSize.values.firstWhere((s) => s.name == fs, orElse: () => PoppyFontSize.medium);
      _lineHeight = PoppyLineHeight.values.firstWhere((l) => l.name == lh, orElse: () => PoppyLineHeight.normal);
    } catch (_) { /* use defaults */ }
    notifyListeners();
  }

  // ── Color setters ─────────────────────────────────────────

  Future<void> setColor(ColorSlot slot, Color color) async {
    _colors[slot.key] = color;
    notifyListeners();
    await _storage.write(key: slot.key, value: _colorToHex(color));
  }

  Future<void> resetColor(ColorSlot slot) async {
    _colors.remove(slot.key);
    notifyListeners();
    await _storage.delete(key: slot.key);
  }

  Future<void> resetAllColors() async {
    _colors.clear();
    notifyListeners();
    for (final slot in ColorSlots.all) {
      await _storage.delete(key: slot.key);
    }
  }

  // ── Font setters ──────────────────────────────────────────

  Future<void> setTitleFont(PoppyFont v) async {
    if (_titleFont == v) return;
    _titleFont = v; notifyListeners();
    await _storage.write(key: StorageKeys.selectedTitleFont, value: v.name);
  }

  Future<void> setBodyFont(PoppyFont v) async {
    if (_bodyFont == v) return;
    _bodyFont = v; notifyListeners();
    await _storage.write(key: StorageKeys.selectedBodyFont, value: v.name);
  }

  Future<void> setFontSize(PoppyFontSize v) async {
    if (_fontSize == v) return;
    _fontSize = v; notifyListeners();
    await _storage.write(key: StorageKeys.selectedFontSize, value: v.name);
  }

  Future<void> setLineHeight(PoppyLineHeight v) async {
    if (_lineHeight == v) return;
    _lineHeight = v; notifyListeners();
    await _storage.write(key: StorageKeys.selectedLineHeight, value: v.name);
  }
}