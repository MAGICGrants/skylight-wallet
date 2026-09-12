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
  String get done => 'Concluir';

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
      'A Skylight Wallet é uma das mais simples carteiras de Monero. Nós o ajudaremos a configurar uma carteira e se conectar à um servidor.';

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
  String get restoreWarningTitle => 'Aviso de Restauração';

  @override
  String get restoreWarningDescription =>
      'Você tem certeza? O servidor ao qual você se conectar poderá ver seu histórico de transações Monero passadas e futuras.';

  @override
  String get restoreWarningContinueButton => 'Continuar';

  @override
  String get lwsSetupTitle => 'Configuração da conexão';

  @override
  String get lwsSetupDescription =>
      'Conecte-se a um servidor light-wallet Monero (LWS) ou ao seu próprio nó completo. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você. Com um LWS, sua chave privada de visualização e seu endereço primário serão compartilhados com este servidor.';

  @override
  String get lwsSetupAddressHint => 'lws.example.com:18090';

  @override
  String get lwsSetupProxyPortLabel => 'Porta do Proxy HTTP (opcional)';

  @override
  String get lwsSetupProxyPortHint => 'ex: 4444 para I2P';

  @override
  String get lwsSetupUseTorLabel => 'Usar Tor';

  @override
  String get lwsSetupTestConnectionButton => 'Testar Conexão';

  @override
  String get lwsSetupStartingTor => 'Iniciando Tor...';

  @override
  String get lwsSetupContinueButton => 'Continuar';

  @override
  String get connectionTypeLws => 'Servidor Light Wallet';

  @override
  String get connectionTypeNode => 'Nó Monero';

  @override
  String get connectionNodeAddressHint => 'ex.: node.example.com:18081';

  @override
  String get connectionRemoteIpNotAllowed =>
      'Conexões com endereços IP remotos não são permitidas. Use um nome de domínio ou um endereço IP local.';

  @override
  String get connectionProtocolHttps => 'Removendo protocolo. Usando HTTPS para domínios.';

  @override
  String get connectionProtocolHttp => 'Removendo protocolo. Usando HTTP para endereços locais.';

  @override
  String get connectionTestStop => 'Parar';

  @override
  String get connectionTestingTitle => 'Testando conexão';

  @override
  String get connectionTestingDetail => 'Verificando se o servidor responde.';

  @override
  String get connectionTestAgain => 'Testar novamente';

  @override
  String get connectionResultWorksTitle => 'A conexão funciona';

  @override
  String get connectionResultFailedTitle => 'Não foi possível acessar este servidor';

  @override
  String get connectionResultFailedDetail =>
      'Nada respondeu. Verifique o endereço e a porta, e se o servidor aceita sua conexão.';

  @override
  String get connectionReachedOverTor => 'Acessado via Tor';

  @override
  String get connectionReachedViaProxy => 'Acessado pelo seu proxy';

  @override
  String get connectionReachedDirect => 'Acessado diretamente';

  @override
  String get connectionIndicatorHttps => 'HTTPS';

  @override
  String get connectionIndicatorLocal => 'Local';

  @override
  String get connectionIndicatorTorInternal => 'Tor Interno';

  @override
  String connectionIndicatorTorExternal(String port) {
    return 'Usando Porta $port';
  }

  @override
  String get settingsConnectionSettingsLabel => 'Configurações de conexão';

  @override
  String get settingsConnectionServerLws => 'LWS';

  @override
  String get settingsConnectionServerNode => 'Nó';

  @override
  String get settingsConnectionOverTor => 'via Tor';

  @override
  String get settingsConnectionOverClearnet => 'via Clearnet';

  @override
  String get settingsConnectionInLocalNetwork => 'na rede local';

  @override
  String get settingsBackgroundSyncLabel => 'Sincronização em segundo plano';

  @override
  String get settingsBackgroundSyncDescription =>
      'Sincroniza o Monero periodicamente em segundo plano para que esteja atualizado ao abrir o app. Só roda enquanto carrega e no WiFi.';

  @override
  String get settingsForegroundSyncLabel => 'Sincronização contínua';

  @override
  String get settingsForegroundSyncDescription =>
      'Mantém o Monero sincronizando continuamente enquanto o app roda em segundo plano, com uma notificação persistente. Usa mais bateria.';

  @override
  String homeBlocksRemaining(String count) {
    return '$count blocos restantes';
  }

  @override
  String get fiatApiSetupTitle => 'Configuração de Exibição de Preços';

  @override
  String get fiatApiSetupDescription =>
      'A Skylight Wallet pode buscar automaticamente o preço mais recente do Monero. Seus saldos não são enviados ao servidor. Como você quer buscar esses dados de preço?';

  @override
  String get fiatApiSettingsModeLabel => 'Modo';

  @override
  String get fiatApiSettingsModeTorOnly => 'Somente Tor';

  @override
  String get fiatApiSettingsModeClearnet => 'Somente Clearnet (não privado)';

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
  String get createWalletTitle => 'Configuração da Carteira';

  @override
  String get createWalletDescription =>
      'Você quer criar uma nova carteira ou restaurar uma carteira existente?';

  @override
  String get createWalletRestoreExistingButton => 'Restaurar Existente';

  @override
  String get createWalletRestoreExistingDesc => 'Insira uma semente Monero existente';

  @override
  String get createWalletCreateNewButton => 'Criar Nova';

  @override
  String get createWalletCreateNewDesc => 'A Skylight Wallet gera uma nova polyseed';

  @override
  String get createWalletPasswordTitle => 'Criar Senha da Carteira';

  @override
  String get createWalletPasswordDescription =>
      'Crie uma senha para proteger sua carteira. Esta senha será necessária para desbloquear sua carteira.';

  @override
  String get createWalletPasswordHint => 'Digite sua senha';

  @override
  String get createWalletConfirmPasswordHint => 'Confirme sua senha';

  @override
  String get passwordTooShortError => 'A senha deve ter pelo menos 8 caracteres.';

  @override
  String get passwordsDoNotMatchError => 'As senhas não coincidem.';

  @override
  String get generateSeedTitle => 'Anote-as, em ordem';

  @override
  String get generateSeedTitleCovered => 'Frase Seed';

  @override
  String get generateSeedDescription =>
      'Esta é a sua polyseed. Anote-a e guarde-a em um lugar seguro.';

  @override
  String get generateSeedSubtitleCovered =>
      'Estas palavras, nesta ordem, são a sua carteira. Anote-as e guarde-as em um cofre físico. Se você perder estas palavras ou compartilhá-las com outra pessoa, perderá seu dinheiro permanentemente. Um planejamento cuidadoso agora evita um possível desastre depois.';

  @override
  String get generateSeedSubtitleRevealed => 'Guarde-as em segurança. Não as compartilhe.';

  @override
  String get generateSeedScreenshotNote =>
      'As capturas de tela estão bloqueadas nesta tela. Certifique-se de que ninguém está olhando por cima do seu ombro.';

  @override
  String get generateSeedReveal => 'Toque para revelar';

  @override
  String get generateSeedConfirm =>
      'Anotei todas as palavras e as guardei em um lugar que só eu posso acessar.';

  @override
  String get generateSeedContinueButton => 'Eu anotei';

  @override
  String get lwsDetailsTitle => 'Detalhes da Carteira';

  @override
  String get lwsDetailsDescription =>
      'Se o seu servidor Light Wallet Monero (LWS) exigir registro, você pode usar estes dados para adicionar esta carteira a esse servidor. Nem todos os servidores exigem registro.';

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
  String get restoreWalletRestoreDateLabel => 'Data de Restauração (opcional)';

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
      'A Skylight Wallet pode ignorar o histórico irrelevante para economizar seu tempo. Escolha o primeiro mês em que você usou a carteira ou selecione Não tenho certeza para verificar tudo. Não há problema em escolher um mês muito antigo, mas é ruim escolher um mês muito recente.';

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
  String get restoreWalletRestoreButton => 'Restaurar';

  @override
  String get restoreWalletInvalidMnemonic => 'Semente inválida.';

  @override
  String get restoreWalletSeedLength => 'Tamanho da semente';

  @override
  String get restoreWalletPaste => 'Colar';

  @override
  String get restoreWalletSeedTypePolyseed => 'Polyseed';

  @override
  String get restoreWalletSeedTypeBip39 => 'BIP39';

  @override
  String get restoreWalletSeedTypeLegacy => 'Legado';

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
      'Esta não é uma frase-semente válida — verifique as palavras e sua ordem.';

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
  String get unlockWithFaceId => 'Desbloquear com Face ID';

  @override
  String get unlockWithTouchId => 'Desbloquear com Touch ID';

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
  String get homeFiatApiError => 'Erro ao conectar ao servidor de preços';

  @override
  String get homeDisconnected => 'Desconectado';

  @override
  String get coinHomeActivityTitle => 'Atividade';

  @override
  String get coinHomeReceived => 'Recebido';

  @override
  String get coinHomeSent => 'Enviado';

  @override
  String get receiveTitle => 'Receber';

  @override
  String get receivePrimaryAddressWarn =>
      'Aviso: A menos que saiba o que está fazendo, por favor use subendereços para melhor privacidade.';

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
  String get sendInvalidAddressError => 'Endereço inválido.';

  @override
  String get sendInsufficientBalanceError => 'Saldo insuficiente.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Saldo insuficiente para cobrir a taxa da rede.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionGeneral => 'Geral';

  @override
  String get settingsSectionBehaviour => 'Comportamento';

  @override
  String get settingsSectionWallet => 'Carteira';

  @override
  String get settingsSectionAbout => 'Sobre';

  @override
  String get settingsNotifyNewTxsLabel => 'Notificações de Transações';

  @override
  String get settingsNotifyNewTxsDescription =>
      'Mostrar uma notificação quando você receber uma transação. Ao conectar-se a um nó Monero, a Sincronização em Segundo Plano também precisa estar ativada.';

  @override
  String get settingsNotifyNewTxsDescriptionIos =>
      'As notificações serão atrasadas para conexões LWS via Tor.';

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
  String get settingsThemeLightDesc => 'Claro e limpo';

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
  String get settingsFiatApiSettingsLabel => 'Configurações de Exibição de Preços';

  @override
  String get settingsLwsViewKeysLabel => 'Chaves de Visualização do LWS';

  @override
  String get settingsLwsViewKeysButton => 'Ver';

  @override
  String get revealSeedAuthReason => 'Confirme sua identidade para ver a frase seed';

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
  String get txDetailsTitle => 'Detalhes da transação';

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
  String get txDetailsReceivedAtLabel => 'Recebido em';

  @override
  String get txDetailsChangeRecipientLabel => 'Destinatário de troco';

  @override
  String get unconfirmed => 'Não confirmado';

  @override
  String get txDetailsCopyHint => 'toque em qualquer valor para copiar';

  @override
  String get txDetailsFailed => 'Esta transação falhou. Os fundos não foram enviados.';

  @override
  String get txDetailsUnknownStatus =>
      'Esta transação não foi confirmada como enviada. Verifique antes de enviar novamente.';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

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
  String get secretKeysTitle => 'Chaves Privadas de Restauração';

  @override
  String get secretKeysDescription =>
      'Estas sementes e chaves restauram o controle total da sua carteira. Qualquer pessoa que as veja pode gastar seus fundos.';

  @override
  String get secretKeysMnemonic => 'Semente';

  @override
  String get secretKeysPublicSpendKey => 'Chave Pública de Gasto';

  @override
  String get secretKeysSecretSpendKey => 'Chave Privada de Gasto';

  @override
  String get secretKeysPublicViewKey => 'Chave Pública de Visualização';

  @override
  String get secretKeysWarning =>
      'Nunca as compartilhe ou insira em qualquer site. Guarde-as offline.';

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
  String get addressBookNameHint => 'Nome';

  @override
  String get addressBookAddressHint => 'Endereço Monero';

  @override
  String get addressBookAddDescription => 'Um nome e um endereço Monero para pagá-lo.';

  @override
  String get addressBookEditDescription => 'Atualize o nome ou o endereço deste contato.';

  @override
  String get addressBookUpdate => 'Atualizar';

  @override
  String get addressBookSave => 'Salvar';

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
  String get sendContactsButton => 'Contatos';

  @override
  String get sendToLabel => 'Para';

  @override
  String get sendPasteButton => 'Colar';

  @override
  String get sendScanButton => 'Escanear';

  @override
  String get sendMaxButton => 'MÁX';

  @override
  String get sendNetworkFee => 'Taxa de rede';

  @override
  String get sendPriorityHeading => 'Prioridade';

  @override
  String get sendPickContactTitle => 'Enviar para um contato';

  @override
  String get sendAvailableSuffix => 'disponível';

  @override
  String get sendFailedToGetFeesError => 'Não foi possível carregar taxas.';

  @override
  String get torInfoTitle => 'Tor Integrado';

  @override
  String get torInfoDescription =>
      'A Skylight Wallet usa automaticamente Tor integrado para proteger suas conexões de internet.';

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
  String get torChoiceBuiltInDesc => 'Incluído na Skylight Wallet · recomendado';

  @override
  String get torChoiceExternalDesc => 'Orbot, ou um daemon que você mesmo executa';

  @override
  String get torChoiceNoTorDesc =>
      'Os servidores aos quais você se conecta podem ver seu endereço IP';

  @override
  String get torChoiceConnected => 'Conectado ao Tor';

  @override
  String get torChoiceTestFailed => 'Falha no teste';

  @override
  String get torChoiceTitle => 'Configuração da Conexão Tor';

  @override
  String get torChoiceSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. De modo geral, como você quer que a Skylight Wallet lide com as conexões Tor?';

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
      'Algumas carteiras estão configuradas para conectar via Tor. Desativar o Tor irá desconectá-las, e elas permanecerão desconectadas até que você reconfigure a conexão.';

  @override
  String get torDisabledWalletsWarningConfirm => 'Desativar o Tor';

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
}
