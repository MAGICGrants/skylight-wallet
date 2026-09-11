import 'package:wallet_ui/wallet_ui.dart' show BrandPalette;

/// Skylight's colour palette — navy grounds; burnt-orange primary in light,
/// Monero orange in dark. Installed in `main()` via
/// `BrandColors.install(skylightPalette)`. Each field is `(lightHex, darkHex)`.
/// The dark column is taken from the design mockup (near-black navy ground,
/// #0A1826, with Monero Orange the reserved accent).
const skylightPalette = BrandPalette(
  // Grounds & sky surfaces
  paper: (0xFFF2F6FA, 0xFF03090F),
  card: (0xFFFFFFFF, 0xFF0C1621),
  surfaceSunken: (0xFFE7F0F7, 0xFF14212D),
  surfaceTinted: (0xFFDEEAF3, 0xFF1A2837),
  surfaceMuted: (0xFFD5E6F0, 0xFF1A2837),
  hairline: (0xFFD5E6F0, 0xFF1A2837),
  border: (0xFFCADEEC, 0xFF1A2837),
  borderStrong: (0xFFB4CFE2, 0xFF213242),
  inputBorder: (0xFFA9C7DE, 0xFF213242),
  frameEdge: (0xFFB4CFE2, 0xFF213242),
  // Ink — night navy in light; sky white in dark
  ink: (0xFF102A4C, 0xFFE8F0F6),
  inverseSurface: (0xFF263F5F, 0xFF1A2837),
  inkMuted: (0xFF5A748F, 0xFF8CA3B8),
  inkFaint: (0xFF7E93AB, 0xFF6E8398),
  inkDisabled: (0xFFAFC2D4, 0xFF4E627A),
  // Brand primary — burnt orange in light, Monero orange in dark
  primary: (0xFFF5681C, 0xFFF2883C),
  primaryDeep: (0xFFDB5B12, 0xFFEC8236),
  // Semantic
  success: (0xFF2F7D6B, 0xFF79D2B8),
  successBg: (0xFFDCEEE9, 0xFF132B27),
  warning: (0xFFC98A2E, 0xFFE0A94E),
  warningBg: (0xFFFBEFDC, 0xFF33291A),
  error: (0xFFB04A2F, 0xFFE0785A),
  errorBg: (0xFFF8E4DC, 0xFF3A241E),
  // Accents — Tor/proxy/https pills (purple/blue/success); orange = brand.
  purple: (0xFF6B4E9E, 0xFFAC9DE6),
  blue: (0xFF37628F, 0xFF7FB6E8),
  orange: (0xFFF5681C, 0xFFF2883C),
  electrum: (0xFF1E8FC9, 0xFF5CB6E6),
  // Accent-tile backgrounds
  surfaceAccent: (0xFFF6E4D6, 0xFF1D2E3F),
  purpleBg: (0xFFEFE9F8, 0xFF1F1D38),
  blueBg: (0xFFE6EEF7, 0xFF122B41),
  orangeBg: (0xFFF6E4D6, 0xFF3A2A18),
  electrumBg: (0xFFDDF0FB, 0xFF152F3E),
);
