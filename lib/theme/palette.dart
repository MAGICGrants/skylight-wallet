import 'package:wallet_ui/wallet_ui.dart' show BrandPalette;

/// Skylight's colour palette — navy grounds + burnt-orange primary (design
/// handoff). Installed in `main()` via `BrandColors.install(skylightPalette)`.
/// Each field is `(lightHex, darkHex)`. The light column is the shipped skin;
/// the dark column is provisional (deep-navy seed, refined in a later pass).
const skylightPalette = BrandPalette(
  // Grounds & sky surfaces
  paper: (0xFFF2F6FA, 0xFF102A4C),
  card: (0xFFFFFFFF, 0xFF16345C),
  surfaceSunken: (0xFFE7F0F7, 0xFF1B3E68),
  surfaceTinted: (0xFFDEEAF3, 0xFF152F54),
  surfaceMuted: (0xFFD5E6F0, 0xFF24466F),
  hairline: (0xFFD5E6F0, 0xFF24466F),
  border: (0xFFCADEEC, 0xFF24466F),
  borderStrong: (0xFFB4CFE2, 0xFF335277),
  inputBorder: (0xFFA9C7DE, 0xFF335277),
  frameEdge: (0xFFB4CFE2, 0xFF335277),
  // Ink — night navy
  ink: (0xFF102A4C, 0xFFE6EFF7),
  inverseSurface: (0xFF263F5F, 0xFF16345C),
  inkMuted: (0xFF5A748F, 0xFFA9C0D8),
  inkFaint: (0xFF7E93AB, 0xFF7E97B3),
  inkDisabled: (0xFFAFC2D4, 0xFF5A748F),
  // Brand primary — Monero orange (Monero-warm in dark)
  primary: (0xFFF5681C, 0xFFED8E4E),
  primaryDeep: (0xFFDB5B12, 0xFFF0A068),
  // Semantic
  success: (0xFF2F7D6B, 0xFF7FB98A),
  successBg: (0xFFDCEEE9, 0xFF21332B),
  warning: (0xFFC98A2E, 0xFFE0A94E),
  warningBg: (0xFFF3E6CE, 0xFF33291A),
  error: (0xFFB04A2F, 0xFFE0785A),
  errorBg: (0xFFF3DED6, 0xFF3A241E),
  // Accents — purple/blue/electrum kept as Spice (Tor/proxy/https pills);
  // orange re-toned to the brand primary.
  purple: (0xFF6B4E9E, 0xFF9E86C9),
  blue: (0xFF37628F, 0xFF6E9BC9),
  orange: (0xFFF5681C, 0xFFE08A4A),
  electrum: (0xFF1E8FC9, 0xFF5CB6E6),
  // Accent-tile backgrounds
  surfaceAccent: (0xFFF6E4D6, 0xFF1B3E68),
  purpleBg: (0xFFEFE9F8, 0xFF2A2440),
  blueBg: (0xFFE6EEF7, 0xFF1E2A3A),
  orangeBg: (0xFFF6E4D6, 0xFF3A2A18),
  electrumBg: (0xFFDDF0FB, 0xFF152F3E),
);
