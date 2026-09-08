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
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get fieldEmptyError => 'Este campo não pode ficar vazio.';

  @override
  String get welcomeDescription =>
      'Uma carteira de autocustódia simples, moderna e de código aberto para Serai e as redes blockchain que Serai suporta: Bitcoin, Ethereum e Monero. Você tem controle total. Mantida pela MAGIC Grants, uma instituição de caridade pública.';

  @override
  String get welcomeGetStarted => 'Começar';

  @override
  String get welcomeAgreePrefix => 'Ao continuar, você concorda com os ';

  @override
  String get welcomeTermsLink => 'Termos de Serviço';

  @override
  String get welcomeAgreeMiddle => ' e a ';

  @override
  String get welcomePrivacyLink => 'Política de Privacidade';

  @override
  String get torChoiceTitle => 'Configuração da Conexão Tor';

  @override
  String get torChoiceSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. Você pode ativar ou desativar o Tor para cada conexão individualmente. De modo geral, como você quer que a Spice Wallet lide com as conexões Tor?';

  @override
  String get torChoiceBuiltInDesc => 'Incluído na Spice Wallet · recomendado';

  @override
  String get torChoiceExternalDesc => 'Orbot, ou um daemon que você mesmo executa';

  @override
  String get torChoiceNoTorDesc =>
      'Os servidores aos quais você se conecta podem ver seu endereço IP';

  @override
  String get torChoiceOrbot => 'Usar Orbot (porta 9050)';

  @override
  String get torChoiceTestFailed => 'Falha no teste';

  @override
  String get torChoiceConnected => 'Conectado ao Tor';

  @override
  String get connectionSetupTitle => 'Configuração da Conexão';

  @override
  String connectionSetupDescription(String type) {
    return 'Informe o endereço do seu $type. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você.';
  }

  @override
  String connectionSetupDescriptionLws(String type) {
    return 'Informe o endereço do seu $type. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você. Sua chave privada de visualização e seu endereço primário serão compartilhados com este servidor.';
  }

  @override
  String get connectionTypeLws => 'Servidor Light Wallet';

  @override
  String get connectionTypeNode => 'Nó Monero';

  @override
  String get lwsSetupAddressHint => 'ex: 192.168.1.1:18090 ou exemplo.com:18090';

  @override
  String get lwsSetupUseTorLabel => 'Usar Tor';

  @override
  String get lwsSetupTestConnectionButton => 'Testar Conexão';

  @override
  String get connectionProxyPortLabel => 'Porta do Proxy HTTP';

  @override
  String get connectionProxyPortHint => 'Opcional';

  @override
  String get connectionTestingTitle => 'Testando conexão';

  @override
  String get connectionTestingDetail => 'Verificando se o servidor responde.';

  @override
  String get connectionTestStop => 'Parar';

  @override
  String get connectionResultWorksTitle => 'A conexão funciona';

  @override
  String get connectionReachedOverTor => 'Acessado via Tor';

  @override
  String get connectionReachedViaProxy => 'Acessado pelo seu proxy';

  @override
  String get connectionReachedDirect => 'Acessado diretamente';

  @override
  String get connectionResultFailedTitle => 'Não foi possível acessar este servidor';

  @override
  String get connectionResultFailedDetail =>
      'Nada respondeu. Verifique o endereço e a porta, e se o servidor aceita sua conexão.';

  @override
  String get connectionTestAgain => 'Testar novamente';

  @override
  String get lwsSetupStartingTor => 'Iniciando Tor...';

  @override
  String get lwsSetupContinueButton => 'Continuar';

  @override
  String get fiatApiSetupTitle => 'Configuração de Exibição de Preços';

  @override
  String get fiatApiSetupDescription =>
      'A Spice Wallet pode buscar automaticamente os preços mais recentes dos ativos. Seus saldos não são enviados ao servidor. Como você quer buscar esses dados de preço?';

  @override
  String get fiatApiSettingsModeLabel => 'Modo';

  @override
  String get fiatApiSettingsModeTorOnly => 'Somente Tor';

  @override
  String get fiatApiSettingsModeClearnet => 'Somente Clearnet';

  @override
  String get fiatApiSettingsModeDisabled => 'Desativado';

  @override
  String get fiatModeTorOnlyDesc => 'Preços buscados pelo Tor · recomendado';

  @override
  String get fiatModeClearnetDesc => 'Não privado, o servidor de preços vê seu endereço IP';

  @override
  String get fiatModeDisabledDesc => 'Sem preços; saldos exibidos apenas em cripto';

  @override
  String get fiatApiSettingsDisplayCurrencyLabel => 'Moeda de Exibição';

  @override
  String get settingsFiatApiSettingsLabel => 'Configurações de Exibição de Preços';

  @override
  String get fiatApiSettingsSheetSubtitle =>
      'Como os preços são obtidos e a moeda em que são exibidos.';

  @override
  String get createWalletTitle => 'Configuração da Carteira';

  @override
  String get createWalletDescription =>
      'Uma única frase seed protege o acesso à sua carteira em todas as redes blockchain. Você quer criar uma nova carteira ou restaurar uma carteira existente?';

  @override
  String get createWalletRestoreExistingButton => 'Restaurar de uma seed';

  @override
  String get createWalletRestoreExistingDesc => 'Qualquer frase BIP39';

  @override
  String get createWalletCreateNewButton => 'Criar uma nova carteira';

  @override
  String get createWalletCreateNewDesc => 'A Spice Wallet gera uma seed BIP39 de 15 palavras';

  @override
  String get generateSeedTitle => 'Anote estas palavras, em ordem';

  @override
  String get generateSeedTitleCovered => 'Frase Seed';

  @override
  String get generateSeedSubtitleCovered =>
      'Estas quinze palavras, nesta ordem, são a sua carteira. Anote-as e guarde-as em um cofre físico. Se você perder estas palavras ou compartilhá-las com outra pessoa, perderá seu dinheiro permanentemente. Um planejamento cuidadoso agora evita um possível desastre depois.';

  @override
  String get generateSeedSubtitleRevealed => 'Guarde-as em segurança. Não as compartilhe.';

  @override
  String get generateSeedScreenshotNote =>
      'As capturas de tela estão bloqueadas nesta tela. Certifique-se de que ninguém está olhando por cima do seu ombro.';

  @override
  String get generateSeedReveal => 'Toque para revelar';

  @override
  String get generateSeedBirthdayLabel => 'Aniversário da carteira';

  @override
  String get generateSeedBirthdayReason => 'Onde uma futura restauração começa a escanear';

  @override
  String get generateSeedConfirm =>
      'Anotei todas as 15 palavras e as guardei em um lugar que só eu posso acessar.';

  @override
  String get generateSeedContinueButton => 'Continuar';

  @override
  String get lwsDetailsDescription =>
      'Se o seu servidor Light Wallet Monero (LWS) exigir registro, você pode usar estes dados para adicionar esta carteira a esse servidor. Nem todos os servidores exigem registro.';

  @override
  String get restoreWalletTitle => 'Restaurar carteira';

  @override
  String get restoreWalletSubtitle => 'Qualquer frase BIP39, da Spice Wallet ou de outra carteira.';

  @override
  String get restoreWalletSeedLength => 'Tamanho da seed';

  @override
  String get restoreWalletPaste => 'Colar';

  @override
  String get restoreWalletScanFrom => 'Escanear a partir de';

  @override
  String get restoreWalletScanFromReason => 'Ignore o histórico irrelevante para economizar tempo';

  @override
  String get restoreWalletNotSet => 'Não definido';

  @override
  String get restoreScanTitle => 'Quando esta carteira recebeu fundos pela primeira vez?';

  @override
  String get restoreScanDescription =>
      'Para alguns ativos, a Spice Wallet pode ignorar o histórico irrelevante para economizar seu tempo. Escolha o primeiro mês em que você usou a carteira ou selecione Não tenho certeza para verificar tudo. Não há problema em escolher um mês muito antigo, mas é ruim escolher um mês muito recente.';

  @override
  String get restoreScanPickMonth => 'Escolher um mês';

  @override
  String get restoreScanNotSure => 'Não tenho certeza';

  @override
  String get restoreScanNotSureDesc =>
      'Escanear tudo. Mais lento nesta configuração inicial, mas não depois. Sempre completo.';

  @override
  String get restoreScanFromStart => 'Genesis';

  @override
  String get restoreScanDone => 'Concluir';

  @override
  String restoreWalletBadWord(int position) {
    return 'A palavra $position não é uma palavra BIP39.';
  }

  @override
  String restoreWalletDidYouMean(String word) {
    return 'Você quis dizer $word?';
  }

  @override
  String get restoreWalletChecksumError =>
      'Esta não é uma frase seed válida — verifique as palavras e a ordem.';

  @override
  String get restoreWalletRestoreButton => 'Restaurar';

  @override
  String get navigationBarHome => 'Início';

  @override
  String get navigationBarSettings => 'Configurações';

  @override
  String get navigationBarHistory => 'Histórico';

  @override
  String get historyTitle => 'Histórico';

  @override
  String get historyFilterBlockchain => 'Rede';

  @override
  String get historyFilterAsset => 'Ativo';

  @override
  String get historyFilterType => 'Tipo';

  @override
  String get historyTypeBridge => 'Ponte';

  @override
  String get historyTypeSwap => 'Troca';

  @override
  String get historyTypeAdd => 'Adicionar';

  @override
  String get historyTypeRemove => 'Remover';

  @override
  String get historyFilterReset => 'Redefinir';

  @override
  String get unlockButton => 'Desbloquear';

  @override
  String get unlockReason => 'Desbloquear carteira';

  @override
  String get unlockUnableToAuthError => 'Não foi possível autenticar.';

  @override
  String get unlockLockedTitle => 'A Spice Wallet está bloqueada';

  @override
  String get unlockWithFaceId => 'Desbloquear com Face ID';

  @override
  String get unlockWithTouchId => 'Desbloquear com Touch ID';

  @override
  String get unlockPasswordLabel => 'Senha';

  @override
  String get unlockPasswordHint => 'Digite sua senha';

  @override
  String get unlockIncorrectPasswordError => 'Senha incorreta. Tente novamente.';

  @override
  String get homeSyncing => 'Sincronizando';

  @override
  String get homeSynced => 'Sincronizado';

  @override
  String homeBlocksRemaining(String count) {
    return '$count blocos restantes';
  }

  @override
  String get homeNoConnection => 'Sem conexão';

  @override
  String get homeCoinNotConfigured => 'Não configurado';

  @override
  String homeAssetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ativos',
      one: '1 ativo',
    );
    return '$_temp0';
  }

  @override
  String get coinHomeAssetsTitle => 'Ativos';

  @override
  String get coinHomeActivityTitle => 'Atividade';

  @override
  String get coinHomeSwap => 'Trocar';

  @override
  String get coinHomeSwapComingSoon => 'Em breve!';

  @override
  String get coinHomeReceived => 'Recebido';

  @override
  String get coinHomeSent => 'Enviado';

  @override
  String get coinHomeAddExplorerTitle => 'Adicione um explorador para ver o histórico';

  @override
  String get coinHomeAddExplorerButton => 'Adicionar explorador';

  @override
  String get homeFiatSource => 'Kraken via Tor';

  @override
  String get homeReceive => 'Receber';

  @override
  String get homeSend => 'Enviar';

  @override
  String get homeNoTransactions => 'Sem transações';

  @override
  String get homeFiatApiError => 'Erro ao conectar ao servidor de preços';

  @override
  String get homeTotalBalanceLabel => 'Saldo Total';

  @override
  String get receiveTitle => 'Receber';

  @override
  String get receivePrimaryAddressWarn =>
      'Aviso: A menos que saiba o que está fazendo, por favor use subendereços para melhor privacidade.';

  @override
  String get receiveServerNoSubaddressesWarn =>
      'Aviso: Este servidor não suporta subendereços. Para melhor privacidade, considere usar um servidor que os suporte. Você está recebendo no seu endereço primário.';

  @override
  String get receiveMaxSubaddressesReachedWarn =>
      'Você atingiu o número máximo de subendereços suportados por este servidor. Este é um endereço já usado.';

  @override
  String get receiveSubaddressTab => 'Subendereço';

  @override
  String get receivePrimaryTab => 'Endereço primário';

  @override
  String get receiveCopyAddress => 'Copiar endereço';

  @override
  String receiveAddressHeading(String coin) {
    return 'Seu endereço $coin';
  }

  @override
  String receiveBlockchainSubtitle(String coin) {
    return 'Blockchain $coin';
  }

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
  String get sendInsufficientBalanceError => 'Saldo insuficiente.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Saldo insuficiente para cobrir a taxa da rede.';

  @override
  String get sendInsufficientGasError => 'Saldo de ETH insuficiente para cobrir a taxa da rede.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionGeneral => 'Geral';

  @override
  String get settingsSectionBehaviour => 'Comportamento';

  @override
  String get settingsSectionAbout => 'Sobre';

  @override
  String get settingsSectionWallet => 'Carteira';

  @override
  String get settingsCoinConnectionSection => 'Conexão';

  @override
  String get settingsCoinKeysSection => 'Chaves';

  @override
  String get settingsCoinConnectionSetup => 'Configuração da Conexão';

  @override
  String get settingsCoinExplorer => 'Explorador';

  @override
  String get settingsCoinNotConfigured => 'Não configurado';

  @override
  String get settingsNotifyNewTxsLabel => 'Notificações de Transações';

  @override
  String get settingsNotifyNewTxsDescription =>
      'Mostrar uma notificação quando você receber uma transação. Ao conectar-se a um nó Monero, a Sincronização em Segundo Plano também precisa estar ativada.';

  @override
  String get settingsNotifyNewTxsDescriptionIos =>
      'Mostrar uma notificação quando você receber uma transação.';

  @override
  String get settingsBackgroundSyncLabel => 'Sincronização em Segundo Plano';

  @override
  String get settingsBackgroundSyncDescription =>
      'Sincroniza suas carteiras periodicamente em segundo plano para que estejam atualizadas ao abrir o app.';

  @override
  String get settingsForegroundSyncLabel => 'Sincronização Contínua';

  @override
  String get settingsForegroundSyncDescription =>
      'Mantém suas carteiras sincronizando continuamente enquanto o app roda em segundo plano, com uma notificação persistente. Usa mais bateria.';

  @override
  String get settingsAppLockLabel => 'Desbloqueio com PIN/Biometria';

  @override
  String get settingsAppLockUnlockReason => 'Desbloquear carteira';

  @override
  String get settingsAppLockUnableToAuthError =>
      'Não foi possível autenticar. Verifique se o desbloqueio de tela está configurado.';

  @override
  String get settingsVerboseLoggingLabel => 'Logs de Diagnóstico';

  @override
  String get settingsTestnetCoinsLabel => 'Moedas Testnet';

  @override
  String get settingsTestnetCoinsDescription =>
      'Mostrar moedas testnet (ex.: Bitcoin Testnet) na lista de moedas.';

  @override
  String get settingsVerboseLoggingDescription =>
      'Registrar operações da carteira em um arquivo de texto na pasta de dados do app para fins de depuração.';

  @override
  String get settingsVerboseLoggingDescriptionIos =>
      'Registrar operações da carteira e permitir exportar os logs para um arquivo de texto.';

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
  String get settingsThemeLightDesc => 'Papel quente, o padrão';

  @override
  String get settingsThemeDarkDesc => 'Fundo escuro, melhor à noite';

  @override
  String get settingsThemeSystemDesc => 'Segue o seu telefone';

  @override
  String get settingsThemeSheetSubtitle => 'Escolha um tema que combine com seu estilo.';

  @override
  String get settingsLanguageLabel => 'Idioma';

  @override
  String get settingsLanguageSheetSubtitle => 'Escolha seu idioma e formato regional.';

  @override
  String get settingsSeedPhraseLabel => 'Frase Seed';

  @override
  String get revealSeedSubtitleCovered =>
      'As mesmas quinze palavras com que esta carteira foi criada, na mesma ordem.';

  @override
  String get revealSeedSubtitleRevealed =>
      'Guarde-as em segurança. Não as compartilhe. Se você perder estas palavras ou compartilhá-las com outra pessoa, perderá seu dinheiro permanentemente.';

  @override
  String get revealSeedBackButton => 'Voltar às configurações';

  @override
  String get revealSeedHideButton => 'Ocultar e voltar';

  @override
  String get revealSeedAuthReason => 'Confirme sua identidade para ver a frase seed';

  @override
  String get done => 'Concluir';

  @override
  String get settingsLwsViewKeysButton => 'Ver';

  @override
  String get settingsDeleteWalletButton => 'Excluir Carteira';

  @override
  String get settingsDeleteWalletDialogText =>
      'Tem certeza que deseja excluir sua carteira? Você perderá acesso à seus fundos, a menos que tenha anotado sua seed.';

  @override
  String get settingsDeleteWalletDialogDeleteButton => 'Excluir';

  @override
  String get txDetailsTitle => 'Detalhes da transação';

  @override
  String get txDetailsCopyHint => 'toque em qualquer valor para copiar';

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
  String get txDetailsChangeRecipientLabel => 'Destinatário de troco';

  @override
  String get lwsKeysTitle => 'Chaves do LWS';

  @override
  String get lwsKeysPrimaryAddress => 'Endereço Primário';

  @override
  String get lwsKeysRestoreHeight => 'Bloco de Restauração';

  @override
  String get lwsKeysSecretViewKey => 'Chave Privada de Visualização';

  @override
  String get lwsKeysWarning =>
      'As capturas de tela estão bloqueadas nesta tela. Certifique-se de que ninguém está olhando por cima do seu ombro.';

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
  String get addressBookEdit => 'Editar';

  @override
  String get addressBookContactName => 'Nome do Contato';

  @override
  String get addressBookNameHint => 'Nome';

  @override
  String get addressBookAddDescription => 'Um nome e ao menos um endereço para pagar essa pessoa.';

  @override
  String get addressBookEditDescription => 'Um nome e ao menos um endereço para pagar essa pessoa.';

  @override
  String get addressBookAddressesLabel => 'Endereços';

  @override
  String get addressBookAddressesNoneYet => 'nenhum ainda';

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
  String invalidAddressForCoin(String coin) {
    return 'Endereço $coin inválido';
  }

  @override
  String get sendPriorityLow => 'Baixa';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'Alta';

  @override
  String get sendFromLabel => 'De';

  @override
  String get sendToLabel => 'Para';

  @override
  String get sendPriorityHeading => 'Prioridade';

  @override
  String get sendAvailableSuffix => 'disponível';

  @override
  String get sendNetworkFee => 'Taxa de rede';

  @override
  String get sendMaxButton => 'MÁX';

  @override
  String get sendPasteButton => 'Colar';

  @override
  String get sendScanButton => 'Escanear';

  @override
  String sendAddressHint(String coin) {
    return 'Endereço $coin';
  }

  @override
  String get sendPickContactTitle => 'Enviar para um contato';

  @override
  String sendPickContactSubtitle(String coin) {
    return 'Escolha um contato com endereço $coin.';
  }

  @override
  String sendContactNoAddress(String coin) {
    return 'Sem endereço $coin';
  }

  @override
  String get sendFailedToGetFeesError => 'Não foi possível carregar taxas.';

  @override
  String get torSettingsTitle => 'Configurações do Tor';

  @override
  String get torSettingsSheetSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. Alterar isto reconecta todas as redes.';

  @override
  String get torSettingsModeBuiltIn => 'Tor Integrado';

  @override
  String get torSettingsModeExternal => 'Tor Externo';

  @override
  String get torSettingsModeDisabled => 'Sem Tor';

  @override
  String get torSettingsSocksPortLabel => 'Porta SOCKS';

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
  String get connectionProtocolHttps => 'Removendo protocolo. Usando HTTPS para domínios.';

  @override
  String get connectionProtocolHttp => 'Removendo protocolo. Usando HTTP para endereços locais.';

  @override
  String get settingsTorSettingsLabel => 'Configurações do Tor';

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
      'Opcionalmente, defina uma instância do explorador Blockscout para carregar o histórico completo de transações. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você.';

  @override
  String get explorerAddressLabel => 'Endereço do Explorador';

  @override
  String get explorerRemovedMessage => 'Explorador removido.';
}
