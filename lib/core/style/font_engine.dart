import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

// Generic font system mechanics. The enum below names this app's fonts and
// the switch in PoppyFontData.style() maps each one to a Google Fonts
// call — that part is inherently tied to which fonts this app ships, so
// when reusing this in another project you'll edit the enum values and
// switch cases for your own font set. The *shape* of PoppyFontData /
// FontPairData (metadata + style()/bold() helpers, title/body pairing) is
// the reusable part.
//
// Renaming note: kept as `PoppyFont` rather than a generic `AppFont` name
// because the enum's value names (e.g. `PoppyFont.lora`) are persisted to
// disk via `.name` — see ThemeProvider. Renaming the enum is safe, but
// renaming individual *values* would silently reset users' saved fonts.

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