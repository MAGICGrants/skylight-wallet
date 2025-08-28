// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get cancel => 'Cancelar';

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
  String get connectionSetupAddressLabel => 'Endereço';

  @override
  String get connectionSetupAddressHint =>
      'ex: 192.168.1.1:18090 ou exemplo.com:18090';

  @override
  String get connectionSetupProxyPortLabel => 'Porta do Proxy (opcional)';

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
  String get restoreWalletTitle => 'Restaurar Carteira';

  @override
  String get restoreWalletDescription =>
      'Insira sua semente Monero abaixo. Verificaremos os formatos comuns.';

  @override
  String get restoreWalletSeedLabel => 'Semente';

  @override
  String get restoreWalletRestoreHeightLabel => 'Altura de Restauração';

  @override
  String get restoreWalletRestoreButton => 'Restaurar';

  @override
  String get navigationBarWallet => 'Carteira';

  @override
  String get navigationBarSettings => 'Configurações';

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
  String get homeTransactionPending => 'Pendente';

  @override
  String get homeTransactionConfirmed => 'Confirmado';

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
  String get sendAddressLabel => 'Endereço';

  @override
  String get sendAmountLabel => 'Valor';

  @override
  String get sendSendButton => 'Enviar';

  @override
  String get sendOpenAliasResolveError => 'OpenAlias inválido.';

  @override
  String get sendInvalidAddressError => 'Endereço inválido.';

  @override
  String get sendInsufficientBalanceError => 'Saldo insuficiente.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsNotifyNewTxs => 'Notificar Novas Transações';

  @override
  String get settingsLanguageLabel => 'Idioma';

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
  String get txDetailsAmountLabel => 'Valor';

  @override
  String get txDetailsFeeLabel => 'Taxa';

  @override
  String get txDetailsTimeAndDateLabel => 'Data e Hora';

  @override
  String get txDetailsConfirmationHeightLabel => 'Altura de Confirmação';

  @override
  String get txDetailsConfirmationsLabel => 'Confirmações';

  @override
  String get txDetailsViewKeyLabel => 'Chave de Visualização';

  @override
  String get txDetailsRecipientsLabel => 'Destinatários';
}
