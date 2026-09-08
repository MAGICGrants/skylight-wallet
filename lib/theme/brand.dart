import 'package:flutter/material.dart';

/// Spice brand design tokens, taken verbatim from the design handoff
/// (brand/screens/README.md + the literal inline styles in
/// `Wallet Screens.dc.html`). One source of truth for `lib/widgets/ui/`.

/// Brand colour tokens. Every value except the chain brands + [onCinnamon]
/// resolves per brightness, so `BrandColors.paper` is cream in light mode and
/// near-black in dark. [setBrightness] is called once per frame from the app's
/// `MaterialApp.builder`, driven by the Theme picker. Because the tokens are no
/// longer `const`, they can't be used inside `const` expressions.
class BrandColors {
  BrandColors._();

  static bool _dark = false;
  static bool get isDark => _dark;

  /// Point the tokens at the light or dark palette. Cheap; safe to call every
  /// build. Only flips on an actual theme change (which rebuilds the tree).
  static void setBrightness(Brightness brightness) => _dark = brightness == Brightness.dark;

  static Color _pick(int light, int dark) => Color(_dark ? dark : light);

  // Grounds & warm surfaces
  static Color get paper => _pick(0xFFFFFDF6, 0xFF171210); // screen bg
  static Color get card => _pick(0xFFFFFFFF, 0xFF211A16); // raised list-item cards
  static Color get surfaceSunken => _pick(0xFFF9F1E4, 0xFF2A211C); // fields, 2ndary btns, tiles
  static Color get surfaceTinted => _pick(0xFFF4EADB, 0xFF241D19); // segmented-control track
  static Color get surfaceMuted => _pick(0xFFF1E6D5, 0xFF3A2E27); // disabled fills, neutral pills
  static Color get hairline => _pick(0xFFF1E6D5, 0xFF3A2E27); // dividers inside cards
  static Color get border => _pick(0xFFEFE3D1, 0xFF3A2E27); // card / tile borders
  static Color get borderStrong => _pick(0xFFE4D5BE, 0xFF4A3A2F);
  static Color get inputBorder => _pick(0xFFD8C1A2, 0xFF4A3A2F);
  static Color get frameEdge => _pick(0xFFD8C7AC, 0xFF4A3A2F);

  // Ink
  static Color get ink => _pick(0xFF2C170C, 0xFFF4E8DA);

  /// A dark chip that stays dark in both modes (with [onCinnamon] text on it) —
  /// e.g. the "tap to reveal" affordance. Unlike [ink], it does not invert.
  static Color get inverseSurface => _pick(0xFF2C170C, 0xFF3A2E27);
  static Color get inkMuted => _pick(0xFF7C6353, 0xFFA6907F);
  static Color get inkFaint => _pick(0xFF9C8571, 0xFF8A7666);
  static Color get inkDisabled => _pick(0xFFC4AE96, 0xFF6B5A4E);

  // Brand
  static Color get cinnamon => _pick(0xFFA0451C, 0xFFC4551F); // primary buttons, selected states
  static Color get cinnamonDeep => _pick(0xFF8A4B24, 0xFFD0785A); // save, links, quieter primary
  static const onCinnamon = Color(0xFFFFFDF6);

  // Semantic
  static Color get success => _pick(0xFF2F7D6B, 0xFF7FB98A);
  static Color get successBg => _pick(0xFFE7F0E6, 0xFF21332B);
  static Color get warning => _pick(0xFFC98A2E, 0xFFE0A94E);
  static Color get warningBg => _pick(0xFFFBEFDC, 0xFF33291A);
  static Color get error => _pick(0xFFB04A2F, 0xFFE0785A);
  static Color get errorBg => _pick(0xFFF8E4DC, 0xFF3A241E);
  // General accent hues (Tor route glyph + history swap type = purple; proxy
  // route glyph + history bridge type = blue; server-kind pill = orange).
  static Color get purple => _pick(0xFF6B4E9E, 0xFF9E86C9);
  static Color get blue => _pick(0xFF37628F, 0xFF6E9BC9);
  static Color get orange => _pick(0xFFBB5F1F, 0xFFDD8A4A);
  // Electrum's light blue — the always-on server-kind pill for Bitcoin.
  static Color get electrum => _pick(0xFF1E8FC9, 0xFF5CB6E6);

  // Accent-tile backgrounds — pastel in light, dark-toned tints of the same hue
  // in dark. Warm one pairs with cinnamon (sheet icons, MAX pill, nudges); the
  // purple/blue ones tint behind their glyphs.
  static Color get surfaceAccent => _pick(0xFFF6E9D6, 0xFF3A2A1C);
  static Color get purpleBg => _pick(0xFFEFE9F8, 0xFF2A2440);
  static Color get blueBg => _pick(0xFFE6EEF7, 0xFF1E2A3A);
  static Color get orangeBg => _pick(0xFFF9E8D6, 0xFF3A2A18);
  static Color get electrumBg => _pick(0xFFDDF0FB, 0xFF152F3E);

  // Chain brand — identical in both modes, so they stay const (usable in const
  // widgets like CoinMark).
  static const monero = Color(0xFFFF6600);
  static const bitcoin = Color(0xFFF7931A);
  static const ethereum = Color(0xFF627EEA);
  static const dai = Color(0xFFF5AC37);
  static const serai = Color(0xFF2F7D6B);
}

class BrandRadii {
  BrandRadii._();
  static const badge = 6.0;
  static const tile = 12.0;
  static const button = 16.0;
  static const field = 18.0;
  static const card = 20.0;
  static const sheet = 22.0;
  static const pill = 999.0;

  static const rTile = BorderRadius.all(Radius.circular(tile));
  static const rButton = BorderRadius.all(Radius.circular(button));
  static const rField = BorderRadius.all(Radius.circular(field));
  static const rCard = BorderRadius.all(Radius.circular(card));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}

class BrandSpacing {
  BrandSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0; // screen gutter
  static const xxl = 32.0;
}

class BrandMotion {
  BrandMotion._();

  /// Universal transition duration for all animated brand widgets.
  static const transition = Duration(milliseconds: 300);
}

class BrandShadows {
  BrandShadows._();
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x142C170C), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const sheet = <BoxShadow>[
    BoxShadow(color: Color(0x382C170C), blurRadius: 40, offset: Offset(0, -10)),
  ];
}

/// Type scale. Ubuntu for UI text; Ubuntu Mono for every number, address, seed
/// word, hash and technical badge. Weights 400/500/700.
class BrandText {
  BrandText._();
  static const _ui = 'Ubuntu';
  static const _mono = 'Ubuntu Mono';
  static const _tnum = [FontFeature.tabularFigures()];

  // Colour-bearing styles are getters so they follow the theme; [buttonLabel]
  // has no colour and stays const.
  static TextStyle get balance => TextStyle(
    fontFamily: _mono,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72, // -.02em
    height: 1,
    color: BrandColors.ink,
    fontFeatures: _tnum,
  );
  static TextStyle get chainBalance => TextStyle(
    fontFamily: _mono,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1,
    color: BrandColors.ink,
    fontFeatures: _tnum,
  );
  static TextStyle get title => TextStyle(
    fontFamily: _ui,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
    height: 1.2,
    color: BrandColors.ink,
  );
  static TextStyle get sheetTitle => TextStyle(
    fontFamily: _ui,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: BrandColors.ink,
  );
  static TextStyle get appBar =>
      TextStyle(fontFamily: _ui, fontSize: 16, fontWeight: FontWeight.w500, color: BrandColors.ink);
  static TextStyle get listTitle => TextStyle(
    fontFamily: _ui,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: BrandColors.ink,
  );
  static TextStyle get body =>
      TextStyle(fontFamily: _ui, fontSize: 14, color: BrandColors.ink, height: 1.5);
  static TextStyle get bodyMuted =>
      TextStyle(fontFamily: _ui, fontSize: 14, color: BrandColors.inkMuted, height: 1.5);
  static TextStyle get caption =>
      TextStyle(fontFamily: _ui, fontSize: 12, color: BrandColors.inkMuted);
  static const buttonLabel = TextStyle(fontFamily: _ui, fontSize: 16, fontWeight: FontWeight.w500);
  static TextStyle get section => TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2, // .12em
    color: BrandColors.inkMuted,
  );
  static TextStyle get mono =>
      TextStyle(fontFamily: _mono, fontSize: 13, color: BrandColors.inkMuted, fontFeatures: _tnum);
  // Inline fiat balance — the hero balance treatment, smaller (row trailing).
  static TextStyle get amount => TextStyle(
    fontFamily: _mono,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: BrandColors.ink,
    fontFeatures: _tnum,
  );
}

/// Material theme built from the brand tokens. Material stays structural
/// plumbing (Scaffold/Navigator); these keep default chrome on-brand. Each
/// builder pins [BrandColors] to its own brightness first so the resolved
/// tokens (surfaces/ink) are captured correctly; the app's `MaterialApp.builder`
/// re-pins per frame for the widget tree.
ThemeData brandLightTheme() => _brandTheme(Brightness.light);
ThemeData brandDarkTheme() => _brandTheme(Brightness.dark);

ThemeData _brandTheme(Brightness brightness) {
  BrandColors.setBrightness(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.cinnamon,
    brightness: brightness,
    primary: BrandColors.cinnamon,
    onPrimary: BrandColors.onCinnamon,
    secondary: BrandColors.cinnamonDeep,
    surface: BrandColors.paper,
    onSurface: BrandColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: BrandColors.paper,
    fontFamily: 'Ubuntu',
  );
}
