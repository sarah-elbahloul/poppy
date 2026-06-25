import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Typography Registry
//  Location: lib/core/style/app_fonts.dart
// ─────────────────────────────────────────────────────────────

/// Enumeration of all supported fonts in the application.
enum PoppyFont {
  lora,
  merriweather,
  crimsonPro,
  sourceSerif,
  libreBaskerville,
  playfair,
  cormorant,
  literata,
  youngSerif,
  dmSerif,
  fraunces,
  bodoniModa,
  caveat,
  kalam,
  shadowsIntoLight,
  sacramento,
  patrickHand,
  indieFlower,
  comfortaa,
  quicksand,
  nunito,
  fredoka,
  poppins,
  inter,
  outfit,
  spaceGrotesk,
  manrope,
  onest,
}

/// Metadata and styling logic for a specific [PoppyFont].
class PoppyFontData {
  /// The unique identifier for the font.
  final PoppyFont id;

  /// The name displayed in the UI.
  final String displayName;

  /// The category this font belongs to (e.g., 'Classic', 'Handwritten').
  final String category;

  /// A short descriptive tagline for the font.
  final String tagline;

  const PoppyFontData({
    required this.id,
    required this.displayName,
    required this.category,
    required this.tagline,
  });

  /// Generates a [TextStyle] using the Google Fonts library.
  TextStyle style(
    Color color, {
    double size = 16,
    double height = 1.8,
    FontWeight weight = FontWeight.w400,
  }) {
    switch (id) {
      case PoppyFont.lora:
        return GoogleFonts.lora(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.merriweather:
        return GoogleFonts.merriweather(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.crimsonPro:
        return GoogleFonts.crimsonPro(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.sourceSerif:
        return GoogleFonts.sourceSerif4(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.libreBaskerville:
        return GoogleFonts.libreBaskerville(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.playfair:
        return GoogleFonts.playfairDisplay(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.cormorant:
        return GoogleFonts.cormorantGaramond(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.literata:
        return GoogleFonts.literata(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.youngSerif:
        return GoogleFonts.youngSerif(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.dmSerif:
        return GoogleFonts.dmSerifDisplay(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.fraunces:
        return GoogleFonts.fraunces(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.bodoniModa:
        return GoogleFonts.bodoniModa(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.caveat:
        return GoogleFonts.caveat(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.kalam:
        return GoogleFonts.kalam(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.shadowsIntoLight:
        return GoogleFonts.shadowsIntoLight(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.sacramento:
        return GoogleFonts.sacramento(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.patrickHand:
        return GoogleFonts.patrickHand(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.indieFlower:
        return GoogleFonts.indieFlower(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.comfortaa:
        return GoogleFonts.comfortaa(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.quicksand:
        return GoogleFonts.quicksand(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.nunito:
        return GoogleFonts.nunito(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.fredoka:
        return GoogleFonts.fredoka(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.poppins:
        return GoogleFonts.poppins(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.inter:
        return GoogleFonts.inter(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.outfit:
        return GoogleFonts.outfit(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.spaceGrotesk:
        return GoogleFonts.spaceGrotesk(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.manrope:
        return GoogleFonts.manrope(fontSize: size, color: color, height: height, fontWeight: weight);
      case PoppyFont.onest:
        return GoogleFonts.onest(fontSize: size, color: color, height: height, fontWeight: weight);
    }
  }

  /// Returns a semi-bold version of the font style.
  TextStyle bold(Color color, {double size = 16, double height = 1.3}) =>
      style(color, size: size, height: height, weight: FontWeight.w600);
}

/// Central registry for all available fonts in the application.
class PoppyFonts {
  PoppyFonts._();

  static const lora = PoppyFontData(id: PoppyFont.lora, displayName: 'Lora', category: 'Classic', tagline: 'Warm like a letter');
  static const merriweather = PoppyFontData(id: PoppyFont.merriweather, displayName: 'Merriweather', category: 'Classic', tagline: 'Your trusty companion');
  static const crimsonPro = PoppyFontData(id: PoppyFont.crimsonPro, displayName: 'Crimson Pro', category: 'Classic', tagline: 'Old bookshop energy');
  static const sourceSerif = PoppyFontData(id: PoppyFont.sourceSerif, displayName: 'Source Serif', category: 'Classic', tagline: 'Editorial elegance');
  static const libreBaskerville = PoppyFontData(id: PoppyFont.libreBaskerville, displayName: 'Libre Baskerville', category: 'Classic', tagline: 'Timeless & grounding');

  static const playfair = PoppyFontData(id: PoppyFont.playfair, displayName: 'Playfair', category: 'Expressive', tagline: 'Dramatic entrances');
  static const cormorant = PoppyFontData(id: PoppyFont.cormorant, displayName: 'Cormorant', category: 'Expressive', tagline: 'Romantic poetry');
  static const literata = PoppyFontData(id: PoppyFont.literata, displayName: 'Literata', category: 'Expressive', tagline: 'Cozy reading nook');
  static const youngSerif = PoppyFontData(id: PoppyFont.youngSerif, displayName: 'Young Serif', category: 'Expressive', tagline: 'A little rebellious');
  static const dmSerif = PoppyFontData(id: PoppyFont.dmSerif, displayName: 'DM Serif', category: 'Expressive', tagline: 'Quiet confidence');
  static const fraunces = PoppyFontData(id: PoppyFont.fraunces, displayName: 'Fraunces', category: 'Expressive', tagline: 'Delightfully weird');
  static const bodoniModa = PoppyFontData(id: PoppyFont.bodoniModa, displayName: 'Bodoni Moda', category: 'Expressive', tagline: 'Black-tie affair');

  static const caveat = PoppyFontData(id: PoppyFont.caveat, displayName: 'Caveat', category: 'Handwritten', tagline: 'Quick thoughts');
  static const kalam = PoppyFontData(id: PoppyFont.kalam, displayName: 'Kalam', category: 'Handwritten', tagline: 'Ink on paper');
  static const shadowsIntoLight = PoppyFontData(id: PoppyFont.shadowsIntoLight, displayName: 'Shadows Into Light', category: 'Handwritten', tagline: 'Dreamy & light');
  static const sacramento = PoppyFontData(id: PoppyFont.sacramento, displayName: 'Sacramento', category: 'Handwritten', tagline: 'Whispered secrets');
  static const patrickHand = PoppyFontData(id: PoppyFont.patrickHand, displayName: 'Patrick Hand', category: 'Handwritten', tagline: 'Ruled notebook');
  static const indieFlower = PoppyFontData(id: PoppyFont.indieFlower, displayName: 'Indie Flower', category: 'Handwritten', tagline: 'Wild & free');

  static const comfortaa = PoppyFontData(id: PoppyFont.comfortaa, displayName: 'Comfortaa', category: 'Friendly', tagline: 'Soft & cozy');
  static const quicksand = PoppyFontData(id: PoppyFont.quicksand, displayName: 'Quicksand', category: 'Friendly', tagline: 'Gentle breeze');
  static const nunito = PoppyFontData(id: PoppyFont.nunito, displayName: 'Nunito', category: 'Friendly', tagline: 'Warm hug');
  static const fredoka = PoppyFontData(id: PoppyFont.fredoka, displayName: 'Fredoka', category: 'Friendly', tagline: 'Pure joy');
  static const poppins = PoppyFontData(id: PoppyFont.poppins, displayName: 'Poppins', category: 'Friendly', tagline: 'Approachable chic');

  static const inter = PoppyFontData(id: PoppyFont.inter, displayName: 'Inter', category: 'Minimalist', tagline: 'Crystal clear');
  static const outfit = PoppyFontData(id: PoppyFont.outfit, displayName: 'Outfit', category: 'Minimalist', tagline: 'Effortless cool');
  static const spaceGrotesk = PoppyFontData(id: PoppyFont.spaceGrotesk, displayName: 'Space Grotesk', category: 'Minimalist', tagline: 'Future diary');
  static const manrope = PoppyFontData(id: PoppyFont.manrope, displayName: 'Manrope', category: 'Minimalist', tagline: 'Quiet luxury');
  static const onest = PoppyFontData(id: PoppyFont.onest, displayName: 'Onest', category: 'Minimalist', tagline: 'Friendly modern');

  /// List of all available [PoppyFontData] objects.
  static const all = [
    lora, merriweather, crimsonPro, sourceSerif, libreBaskerville,
    playfair, cormorant, literata, youngSerif, dmSerif, fraunces, bodoniModa,
    caveat, kalam, shadowsIntoLight, sacramento, patrickHand, indieFlower,
    comfortaa, quicksand, nunito, fredoka, poppins,
    inter, outfit, spaceGrotesk, manrope, onest,
  ];

  /// List of available font categories.
  static const categories = ['Classic', 'Expressive', 'Handwritten', 'Friendly', 'Minimalist'];

  /// Returns a list of fonts belonging to the specified [category].
  static List<PoppyFontData> byCategory(String category) =>
      all.where((f) => f.category == category).toList();

  /// Retrieves [PoppyFontData] for a given [PoppyFont] ID.
  ///
  /// Defaults to [lora] if not found.
  static PoppyFontData fromId(PoppyFont id) =>
      all.firstWhere((f) => f.id == id, orElse: () => lora);
}

/// A combined data structure representing a paired title font and body font.
class FontPairData {
  final PoppyFontData _titleFont;
  final PoppyFontData _bodyFont;

  const FontPairData(this._titleFont, this._bodyFont);

  /// The font designated for titles.
  PoppyFontData get titleFont => _titleFont;

  /// The font designated for body text.
  PoppyFontData get bodyFont => _bodyFont;

  /// Returns a serif style based on the body font.
  TextStyle serifStyle(Color c, {double size = 16, double height = 1.8}) =>
      _bodyFont.style(c, size: size, height: height);

  /// Returns a bold serif style based on the title font.
  TextStyle serifBold(Color c, {double size = 16, double height = 1.3}) =>
      _titleFont.bold(c, size: size, height: height);

  /// Returns a sans-serif style based on the body font.
  TextStyle sansStyle(Color c, {double size = 14, double height = 1.4}) =>
      _bodyFont.style(c, size: size, height: height);

  /// Returns a bold sans-serif style based on the title font.
  TextStyle sansBold(Color c, {double size = 14, double height = 1.4}) =>
      _titleFont.bold(c, size: size, height: height);
}
