// App directories live in wallet-core (wallet_infra/paths). The app dir name is
// installed via WalletAppConfig.install (wallet_core_glue.dart). Kept under this
// path so call sites are unchanged.
export 'package:wallet_infra/wallet_infra.dart'
    show getAppDir, createAppDir, cleanTorDirectoriesOnIOS;
