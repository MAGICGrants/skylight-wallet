// FiatRateModel lives in wallet-core (`wallet_fiat`, multicoin — skylight uses
// the XMR result via rateFor('XMR')). Kept under the same import path so call
// sites are unchanged; the app supplies the Tor proxy via FiatRates.install and
// attaches the WalletManager via attachFiatWalletManager in wallet_core_glue.dart.
// The fiatAutoDisabledByTor auto-disable/restore stays app-side (tor_settings_form).
export 'package:wallet_fiat/wallet_fiat.dart' show FiatRateModel, FiatApiMode;
