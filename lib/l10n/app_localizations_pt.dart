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
  String get close => 'Fechar';

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
  String get copy => 'Copiar';

  @override
  String get addressCopied => 'Endereço copiado para a área de transferência';

  @override
  String get fieldEmptyError => 'Este campo não pode ficar vazio.';

  @override
  String get welcomeTitle => 'Bem-vindo!';

  @override
  String get welcomeDescription =>
      'A Skylight é uma das mais simples carteiras de Monero. Nós o ajudaremos a configurar uma carteira e se conectar à um servidor.';

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
      'Vamos configurar uma conexão com seu servidor light-wallet de Monero (LWS).';

  @override
  String get connectionSetupAddressHint => 'ex: 192.168.1.1:18090 ou exemplo.com:18090';

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
  String get connectionSetupStartingTor => 'Iniciando Tor...';

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
  String get restoreWalletRestoreHeightLabel => 'Bloco de Restauração (opcional)';

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
  String get unlockTitle => 'Desbloquear Carteira';

  @override
  String get unlockDescription => 'Digite a senha da sua carteira para desbloquear';

  @override
  String get unlockPasswordLabel => 'Senha';

  @override
  String get unlockPasswordHint => 'Digite sua senha';

  @override
  String get unlockIncorrectPasswordError => 'Senha incorreta. Tente novamente.';

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
      'Aviso: A menos que saiba o que está fazendo, por favor considere usar subendereços para melhor privacidade.';

  @override
  String get receiveShareButton => 'Compartilhar';

  @override
  String get receiveShowSubaddressButton => 'Mostrar Subendereço';

  @override
  String get receiveShowPrimaryAddressButton => 'Mostrar Endereço Primário';

  @override
  String get receiveServerNoSubaddressesWarn =>
      'Aviso: Este servidor não suporta subendereços. Para melhor privacidade, considere usar um servidor que os suporte. Você está recebendo no seu endereço primário.';

  @override
  String get receiveMaxSubaddressesReachedWarn =>
      'Você atingiu o número máximo de subendereços suportados por este servidor. Este é um endereço já usado.';

  @override
  String get sendTitle => 'Enviar';

  @override
  String get sendSendButton => 'Enviar';

  @override
  String get sendTransactionSuccessfullySent => 'Transação enviada com sucesso!';

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
  String get settingsAppLockUnableToAuthError =>
      'Não foi possível autenticar. Verifique se o desbloqueio de tela está configurado.';

  @override
  String get settingsVerboseLoggingLabel => 'Logs Detalhados';

  @override
  String get settingsVerboseLoggingDescription =>
      'Registra operações da carteira em um arquivo de texto na pasta de dados do app para fins de depuração.';

  @override
  String get settingsVerboseLoggingDescriptionIos =>
      'Registra operações da carteira e permite exportar os logs para um arquivo de texto.';

  @override
  String get settingsExportLogsLabel => 'Exportar Logs';

  @override
  String get settingsExportLogsButton => 'Exportar';

  @override
  String get settingsExportLogsError => 'Nenhum log encontrado para exportar.';

  @override
  String get settingsThemeLabel => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

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
      'Somente compartilhe estas informações com o seu servidor light-wallet. Essas chaves permitem que o portador veja permanentemente todas as transações relacionadas às suas carteiras. Compartilhá-las com uma pessoa não confiável prejudicará significativamente sua privacidade.';

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
  String get confirmSendTitle => 'Confirmar Envio';

  @override
  String get confirmSendDescription =>
      'As transações são irreversíveis, então verifique se estes detalhes correspondem exatamente.';

  @override
  String get addressBookTitle => 'Lista de Contatos';

  @override
  String get addressBookAddContact => 'Adicionar Contato';

  @override
  String get addressBookEditContact => 'Editar Contato';

  @override
  String get addressBookDeleteContact => 'Excluir Contato';

  @override
  String addressBookDeleteContactConfirmation(String contactName) {
    return 'Tem certeza que deseja excluir \"$contactName\"?';
  }

  @override
  String get addressBookDelete => 'Excluir';

  @override
  String get addressBookSearchHint => 'Pesquisar contatos...';

  @override
  String get addressBookNoContacts => 'Nenhum contato ainda';

  @override
  String get addressBookNoContactsDescription => 'Adicione seu primeiro contato tocando no botão +';

  @override
  String get addressBookNoSearchResults => 'Nenhum contato encontrado';

  @override
  String get addressBookCopyAddress => 'Copiar Endereço';

  @override
  String get addressBookEdit => 'Editar';

  @override
  String get addressBookContactName => 'Nome do Contato';

  @override
  String get addressBookUpdate => 'Atualizar';

  @override
  String get addressBookSave => 'Salvar';

  @override
  String get sendSelectFromAddressBook => 'Selecionar da Lista de Contatos';

  @override
  String get sendSelectedContact => 'Contato selecionado';

  @override
  String get sendClearSelectedContact => 'Limpar contato selecionado';

  @override
  String get sendEditAddress => 'Editar Endereço';

  @override
  String get sendPriorityLow => 'Baixa';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'Alta';

  @override
  String get sendPriorityLabel => 'prioridade';

  @override
  String get sendTransactionPriority => 'Prioridade da Transação';

  @override
  String get sendFeeLabel => 'Taxa';

  @override
  String get sendBalanceLabel => 'Saldo';

  @override
  String get sendFailedToGetFeesError => 'Não foi possível carregar taxas.';

  @override
  String get torInfoTitle => 'Tor Integrado';

  @override
  String get torInfoDescription =>
      'A Carteira Skylight usa automaticamente Tor integrado para proteger suas conexões de internet.';

  @override
  String get torInfoContinueButton => 'Continuar';

  @override
  String get torInfoConfigureButton => 'Configurar';

  @override
  String get torSettingsTitle => 'Configurações do Tor';

  @override
  String get torSettingsModeLabel => 'Modo Tor';

  @override
  String get torSettingsModeBuiltIn => 'Tor Integrado';

  @override
  String get torSettingsModeExternal => 'Tor Externo';

  @override
  String get torSettingsModeDisabled => 'Sem Tor';

  @override
  String get torSettingsSocksPortLabel => 'Porta SOCKS';

  @override
  String get torSettingsSocksPortHint => 'ex: 9050';

  @override
  String get torSettingsUseOrbotLabel => 'Usar Orbot/InviZible';

  @override
  String get torSettingsSaveButton => 'Salvar';

  @override
  String get torSettingsTestConnectionButton => 'Testar Conexão';

  @override
  String get settingsConnectionSettingsLabel => 'Configurações da Conexão';

  @override
  String get settingsTorSettingsLabel => 'Configurações do Tor';

  @override
  String get connectionSetupUsingInternalTor => 'Usando Tor interno';

  @override
  String connectionSetupUsingExternalTor(String address) {
    return 'Usando proxy Tor externo em $address';
  }

  @override
  String get connectionSetupTorDisabledError =>
      'O Tor está desativado. Por favor, volte e ative-o.';
}
