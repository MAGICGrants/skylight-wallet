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
  String get lwsSetupTitle => 'Configuração do LWS';

  @override
  String get lwsSetupDescription => 'Informe o endereço do seu servidor light-wallet Monero (LWS).';

  @override
  String get connectionSetupTitle => 'Configuração da Conexão';

  @override
  String connectionSetupDescription(String type) {
    return 'Informe o endereço do seu $type.';
  }

  @override
  String get connectionTypeLws => 'Servidor Light Wallet';

  @override
  String get connectionTypeNode => 'Nó Monero';

  @override
  String get lwsSetupAddressHint => 'ex: 192.168.1.1:18090 ou exemplo.com:18090';

  @override
  String get lwsSetupProxyPortLabel => 'Porta do Proxy HTTP (opcional)';

  @override
  String get lwsSetupProxyPortHint => 'ex: 4444 para I2P';

  @override
  String get lwsSetupUseTorLabel => 'Usar Tor';

  @override
  String get lwsSetupUseSslLabel => 'Usar SSL';

  @override
  String get lwsSetupTestConnectionButton => 'Testar Conexão';

  @override
  String get lwsSetupStartingTor => 'Iniciando Tor...';

  @override
  String get lwsSetupContinueButton => 'Continuar';

  @override
  String get fiatApiSetupTitle => 'Exibição de Saldo em Fiat';

  @override
  String get fiatApiSetupDescription => 'Preço de referência opcional para seu saldo em XMR.';

  @override
  String get fiatApiSettingsModeLabel => 'Modo';

  @override
  String get fiatApiSettingsModeTorOnly => 'Somente Tor';

  @override
  String get fiatApiSettingsModeClearnet => 'Somente Clearnet (não privado)';

  @override
  String get fiatApiSettingsModeDisabled => 'Desativado';

  @override
  String get fiatApiSettingsDisplayCurrencyLabel => 'Moeda de Exibição';

  @override
  String get createWalletTitle => 'Criar Carteira';

  @override
  String get createWalletDescription =>
      'Você já possui uma seed de carteira Monero ou precisa criar uma nova?';

  @override
  String get createWalletRestoreExistingButton => 'Restaurar Existente';

  @override
  String get createWalletCreateNewButton => 'Criar Nova';

  @override
  String get generateSeedTitle => 'Nova Carteira';

  @override
  String get generateSeedDescription =>
      'Esta é a sua seed de 15 palavras. Anote-a e guarde-a em um lugar seguro. Ela pode restaurar todas as moedas desta carteira.';

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
      'Insira sua seed de 15 palavras para restaurar todas as moedas desta carteira.';

  @override
  String get restoreWalletSeedLabel => 'Seed';

  @override
  String get restoreWalletRestoreHeightLabel => 'Bloco de Restauração (opcional)';

  @override
  String get restoreWalletRestoreDateLabel => 'Restaurar a partir da data';

  @override
  String get restoreWalletRestoreButton => 'Restaurar';

  @override
  String get restoreWalletInvalidMnemonic => 'Seed inválida.';

  @override
  String get navigationBarWallet => 'Carteira';

  @override
  String get navigationBarSettings => 'Configurações';

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
  String get homeFiatApiError => 'Erro ao conectar à API de cotação';

  @override
  String get homeTotalBalanceLabel => 'Saldo Total';

  @override
  String get homeYourCoinsTitle => 'Suas Moedas';

  @override
  String get homeCoinNotConfigured => 'Não configurado';

  @override
  String get homeCoinSetUp => 'Configurar';

  @override
  String get homeConnectionErrorTooltip => 'Não foi possível conectar ao servidor';

  @override
  String get coinHomeServerConnectionButton => 'Conexão com o servidor';

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
  String get sendContactsButton => 'Contatos';

  @override
  String get sendInvalidAddressError => 'Endereço inválido.';

  @override
  String get sendInsufficientBalanceError => 'Saldo insuficiente.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Saldo insuficiente para cobrir a taxa da rede.';

  @override
  String get sendInsufficientGasError => 'Saldo de ETH insuficiente para cobrir a taxa da rede.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String homeBlocksRemaining(String count) {
    return '$count blocos restantes';
  }

  @override
  String get settingsNotifyNewTxsLabel => 'Notificar Novas Transações';

  @override
  String get settingsBackgroundSyncLabel => 'Sincronização em Segundo Plano';

  @override
  String get settingsBackgroundSyncDescription =>
      'Sincroniza o Monero periodicamente em segundo plano para que esteja atualizado ao abrir o app.';

  @override
  String get settingsBackgroundSyncIntervalLabel => 'Intervalo de Sincronização';

  @override
  String get settingsForegroundSyncLabel => 'Sincronização Contínua';

  @override
  String get settingsForegroundSyncDescription =>
      'Mantém o Monero sincronizando continuamente enquanto o app roda em segundo plano, com uma notificação persistente. Usa mais bateria.';

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
  String get settingsTestnetCoinsLabel => 'Moedas Testnet';

  @override
  String get settingsTestnetCoinsDescription =>
      'Mostrar moedas testnet (ex.: Bitcoin Testnet) na lista de moedas.';

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
  String get settingsFiatApiSettingsLabel => 'Configs. da API de Moeda Local';

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
      'Tem certeza que deseja excluir sua carteira? Você perderá acesso à seus fundos, a menos que tenha anotado sua seed.';

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
  String get txDetailsChangeRecipientLabel => 'Troco';

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
  String get secretKeysMnemonic => 'Seed';

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
  String confirmSendHighFeeWarning(String percent) {
    return 'A taxa de rede é $percent do valor que você está enviando.';
  }

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
  String get addressBookAtLeastOneAddressError => 'Informe pelo menos um endereço';

  @override
  String addressBookNoContactsForCoin(String coinSymbol) {
    return 'Nenhum contato com endereço $coinSymbol';
  }

  @override
  String get sendSelectedContact => 'Contato selecionado';

  @override
  String get sendClearSelectedContact => 'Limpar contato selecionado';

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
  String get torSettingsUseOrbotLabelIos => 'Usar Orbot';

  @override
  String get torSettingsSaveButton => 'Salvar';

  @override
  String get torSettingsTestConnectionButton => 'Testar Conexão';

  @override
  String get torDisabledWalletsWarningTitle => 'Desativar o Tor?';

  @override
  String get torDisabledWalletsWarningBody =>
      'Algumas carteiras estão configuradas para conectar via Tor. Desativar o Tor irá desconectá-las, e elas permanecerão desconectadas até que você reconfigure a conexão delas.';

  @override
  String get torDisabledWalletsWarningConfirm => 'Desativar o Tor';

  @override
  String get connectionRemoteIpNotAllowed =>
      'Conexões com endereços IP remotos não são permitidas. Use um nome de domínio ou um endereço IP local.';

  @override
  String get connectionIndicatorTorInternal => 'Tor Interno';

  @override
  String connectionIndicatorTorExternal(String port) {
    return 'Usando Porta $port';
  }

  @override
  String get connectionIndicatorHttps => 'HTTPS';

  @override
  String get connectionIndicatorLocal => 'Local';

  @override
  String get connectionProtocolHttps => 'Removendo protocolo. Usando HTTPS para domínios.';

  @override
  String get connectionProtocolHttp => 'Removendo protocolo. Usando HTTP para endereços locais.';

  @override
  String get settingsLwsSettingsLabel => 'Configurações do LWS';

  @override
  String get settingsTorSettingsLabel => 'Configurações do Tor';

  @override
  String get lwsSetupUsingInternalTor => 'Usando Tor interno';

  @override
  String lwsSetupUsingExternalTor(String address) {
    return 'Usando proxy Tor externo em $address';
  }

  @override
  String get lwsSetupTorDisabledError => 'O Tor está desativado. Por favor, volte e ative-o.';

  @override
  String get lwsSetupInvalidQrCode => 'Endereço de conexão inválido.';

  @override
  String get save => 'Salvar';

  @override
  String get explorerSetupTitle => 'Configuração do Explorador de Blocos';

  @override
  String get explorerSetupDescription =>
      'Opcionalmente, defina uma instância Blockscout para carregar o histórico completo de transações. Deixe em branco para desativar — as transações enviadas futuras continuam aparecendo sem ele.';

  @override
  String get explorerAddressLabel => 'Endereço do Explorador';

  @override
  String get explorerRemoveButton => 'Remover Explorador';

  @override
  String get explorerRemovedMessage => 'Explorador removido.';

  @override
  String get explorerSetupButton => 'Configurar Explorador';

  @override
  String get explorerSetupHint =>
      'Configure um explorador de blocos para ver seu histórico completo de transações.';

  @override
  String get legacyTitle => 'Carteira Não Suportada';

  @override
  String get legacyDescription =>
      'A Skylight Wallet está descontinuando o suporte a frases seed legacy e polyseed em favor do BIP39. Por favor, anote a frase seed abaixo, exclua esta carteira e crie uma nova carteira com seed BIP39. Você pode restaurar esta seed em outra carteira Monero e mover os fundos para sua nova carteira BIP39.';

  @override
  String get legacyShowSeedButton => 'Mostrar seed';

  @override
  String get legacySeedLabel => 'Seed';

  @override
  String get legacyError =>
      'Não foi possível abrir a carteira. Verifique sua senha e tente novamente.';
}
