// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get continueText => 'Continuar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get unknownError => 'Erro desconhecido.';

  @override
  String get warning => 'Atenção';

  @override
  String get amount => 'Valor';

  @override
  String get networkFee => 'Taxa da Rede';

  @override
  String get address => 'Endereço';

  @override
  String get pending => 'Pendente';

  @override
  String get fieldEmptyError => 'Este campo não pode ficar vazio.';

  @override
  String get welcomeTitle => 'Bem-vindo!';

  @override
  String get welcomeDescription =>
      'A Light Monero Wallet é uma das carteiras Monero mais simples. Nós o ajudaremos a configurar uma carteira e se conectar a um servidor.';

  @override
  String get welcomeGetStarted => 'Começar';

  @override
  String get restoreWarningTitle => 'Aviso de Restauração';

  @override
  String get restoreWarningDescription =>
      'Você tem certeza? O servidor ao qual você se conectar poderá ver seu histórico de transações Monero passadas e futuras.';

  @override
  String get restoreWarningContinueButton => 'Continuar';

  @override
  String get connectionSetupTitle => 'Configuração da Conexão';

  @override
  String get connectionSetupDescription =>
      'Vamos configurar uma conexão com o LWS.';

  @override
  String get connectionSetupAddressHint =>
      'ex: 192.168.1.1:18090 ou exemplo.com:18090';

  @override
  String get connectionSetupProxyPortLabel => 'Porta do Proxy HTTP (opcional)';

  @override
  String get connectionSetupProxyPortHint => 'ex: 4444 para I2P';

  @override
  String get connectionSetupUseTorLabel => 'Usar Tor';

  @override
  String get connectionSetupUseSslLabel => 'Usar SSL';

  @override
  String get connectionSetupTestConnectionButton => 'Testar Conexão';

  @override
  String get connectionSetupContinueButton => 'Continuar';

  @override
  String get createWalletTitle => 'Criar Carteira';

  @override
  String get createWalletDescription =>
      'Você já possui uma semente de carteira Monero ou precisa criar uma nova?';

  @override
  String get createWalletRestoreExistingButton => 'Restaurar Existente';

  @override
  String get createWalletCreateNewButton => 'Criar Nova';

  @override
  String get generateSeedTitle => 'Nova Carteira';

  @override
  String get generateSeedDescription =>
      'Esta é a sua polyseed. Anote-a e guarde-a em um lugar seguro.';

  @override
  String get generateSeedContinueButton => 'Eu anotei';

  @override
  String get lwsDetailsTitle => 'Detalhes da Carteira';

  @override
  String get lwsDetailsDescription =>
      'Você pode usar esses detalhes para permitir essa carteira no seu servidor de light wallet caso necessário.';

  @override
  String get lwsDetailsPrimaryAddressLabel => 'Endereço Primário';

  @override
  String get lwsDetailsSecretViewKeyLabel => 'Chave Privada de Visualização';

  @override
  String get lwsDetailsRestoreHeightLabel => 'Bloco de Restauração';

  @override
  String get restoreWalletTitle => 'Restaurar Carteira';

  @override
  String get restoreWalletDescription =>
      'Insira sua semente Monero abaixo. Verificaremos os formatos comuns.';

  @override
  String get restoreWalletSeedLabel => 'Semente';

  @override
  String get restoreWalletRestoreHeightLabel => 'Bloco de Restauração';

  @override
  String get restoreWalletRestoreButton => 'Restaurar';

  @override
  String get restoreWalletInvalidMnemonic => 'Semente inválida.';

  @override
  String get navigationBarWallet => 'Carteira';

  @override
  String get navigationBarSettings => 'Configurações';

  @override
  String get navigationBarKeys => 'Chaves';

  @override
  String get unlockButton => 'Desbloquear';

  @override
  String get unlockReason => 'Desbloquear carteira';

  @override
  String get unlockUnableToAuthError => 'Não foi possível autenticar.';

  @override
  String get homeConnecting => 'Conectando';

  @override
  String get homeSyncing => 'Sincronizando';

  @override
  String get homeHeight => 'Bloco';

  @override
  String get homeReceive => 'Receber';

  @override
  String get homeSend => 'Enviar';

  @override
  String get homeBalanceLocked => 'travado';

  @override
  String get homeTransactionsTitle => 'Transações';

  @override
  String get homeOutgoingTxSemanticLabel => 'Transação de Saída';

  @override
  String get homeIncomingTxSemanticLabel => 'Transação de Entrada';

  @override
  String get homeTransactionConfirmed => 'Confirmado';

  @override
  String get homeNoTransactions => 'Sem transações';

  @override
  String get receiveTitle => 'Receber';

  @override
  String get receivePrimaryAddressWarn =>
      'Aviso: Para maior privacidade, considere usar subendereços se o seu servidor de light wallet os suportar.';

  @override
  String get receiveSubaddressWarn =>
      'Aviso: Certifique-se de que seu servidor de light wallet suporta subendereços, caso contrário, você não conseguirá ver as transações recebidas.';

  @override
  String get receiveShareButton => 'Compartilhar';

  @override
  String get receiveShowSubaddressButton => 'Mostrar Subendereço';

  @override
  String get receiveShowPrimaryAddressButton => 'Mostrar Endereço Primário';

  @override
  String get sendTitle => 'Enviar';

  @override
  String get sendSendButton => 'Enviar';

  @override
  String get sendTransactionSuccessfullySent =>
      'Transação enviada com sucesso!';

  @override
  String get sendOpenAliasResolveError => 'OpenAlias inválido.';

  @override
  String get sendInvalidAddressError => 'Endereço inválido.';

  @override
  String get sendInsufficientBalanceError => 'Saldo insuficiente.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Saldo insuficiente para cobrir a taxa da rede.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsNotifyNewTxsLabel => 'Notificar Novas Transações';

  @override
  String get settingsAppLockLabel => 'Desbloqueio com PIN/Biometria';

  @override
  String get settingsAppLockUnlockReason => 'Desbloquear carteira';

  @override
  String get settingsAppLockUnableToAuthError => 'Não foi possível autenticar.';

  @override
  String get settingsLanguageLabel => 'Idioma';

  @override
  String get settingsDisplayCurrencyLabel => 'Moeda Local';

  @override
  String get settingsLwsViewKeysLabel => 'Chaves de Visualização do LWS';

  @override
  String get settingsLwsViewKeysButton => 'Ver';

  @override
  String get settingsSecretKeysLabel => 'Chaves Privadas de Restauração';

  @override
  String get settingsSecretKeysButton => 'Ver';

  @override
  String get settingsViewLwsKeysDialogText =>
      'Somente compartilhe estas informações com o seu servidor LWS. Essas chaves permitem que o portador veja permanentemente todas as transações relacionadas às suas carteiras. Compartilhá-las com uma pessoa não confiável prejudicará significativamente sua privacidade.';

  @override
  String get settingsViewLwsKeysDialogRevealButton => 'Revelar';

  @override
  String get settingsViewSecretKeysDialogText =>
      'Não compartilhe essas chaves com ninguém, incluindo pessoas que aleguem ser suporte. Se você receber um pedido para fornecê-las, está sendo vítima de um golpe. Se você fornecer essas informações a outra pessoa, perderá seu dinheiro e ele não poderá ser recuperado.';

  @override
  String get settingsViewSecretKeysDialogRevealButton => 'Revelar';

  @override
  String get settingsDeleteWalletButton => 'Excluir Carteira';

  @override
  String get settingsDeleteWalletDialogText =>
      'Tem certeza que deseja excluir sua carteira? Você perderá acesso à seus fundos, a menos que tenha anotado sua semente.';

  @override
  String get settingsDeleteWalletDialogDeleteButton => 'Excluir';

  @override
  String get txDetailsTitle => 'Transação';

  @override
  String get txDetailsHashLabel => 'Hash';

  @override
  String get txDetailsTimeAndDateLabel => 'Data e Hora';

  @override
  String get txDetailsConfirmationHeightLabel => 'Bloco de Confirmação';

  @override
  String get txDetailsConfirmationsLabel => 'Confirmações';

  @override
  String get txDetailsViewKeyLabel => 'Chave de Visualização';

  @override
  String get txDetailsRecipientsLabel => 'Destinatários';

  @override
  String get lwsKeysTitle => 'Chaves do LWS';

  @override
  String get lwsKeysPrimaryAddress => 'Endereço Primário';

  @override
  String get lwsKeysRestoreHeight => 'Bloco de Restauração';

  @override
  String get lwsKeysSecretViewKey => 'Chave Privada de Visualização';

  @override
  String get secretKeysTitle => 'Chaves Privadas de Restauração';

  @override
  String get secretKeysMnemonic => 'Semente';

  @override
  String get secretKeysPublicSpendKey => 'Chave Pública de Gasto';

  @override
  String get secretKeysSecretSpendKey => 'Chave Privada de Gasto';

  @override
  String get secretKeysPublicViewKey => 'Chave Pública de Visualização';

  @override
  String get scanQrTitle => 'Escanear QR Code';

  @override
  String get confirmSendTitle => 'Confirm Send';

  @override
  String get confirmSendDescription =>
      'Transactions are irreversible, so make sure that these details match exactly.';
}
