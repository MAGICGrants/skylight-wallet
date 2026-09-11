// NotificationService lives in wallet-core (shared, with its plumbing + the
// background-isolate init guard skylight pioneered). Kept under the same import
// path so call sites are unchanged; the notification text is built by the caller
// (see wallet_core_glue.dart) so it stays coin-correct. Windows branding statics
// are set in installWalletCore().
export 'package:wallet_infra/wallet_infra.dart' show NotificationService;
