// cacert handling lives in wallet-core (wallet_infra); the asset itself is
// bundled by this app (assets/cacert.pem). Kept under this path so call sites
// are unchanged.
export 'package:wallet_infra/wallet_infra.dart' show copyCacertToAppDocumentsDir, getCacertFile;
