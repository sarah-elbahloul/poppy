import 'font_engine.dart';

// This app's specific font catalog. When reusing the font_engine.dart
// mechanism in another project, this is the file to replace with your own
// font choices, names, and taglines.

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