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
  String get back => 'Voltar';

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
  String get lwsSetupTitle => 'Configuração da conexão';

  @override
  String get lwsSetupDescription =>
      'Conecte-se a um servidor light-wallet Monero (LWS) ou ao seu próprio nó completo. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você. Com um LWS, sua chave privada de visualização e seu endereço primário serão compartilhados com este servidor.';

  @override
  String get lwsSetupProxyPortLabel => 'Porta do Proxy HTTP (opcional)';

  @override
  String get lwsSetupProxyPortHint => '4444 para I2P';

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
  String get generateSeedBirthdayLabel => 'Aniversário da carteira';

  @override
  String get generateSeedBirthdayReason => 'Onde uma futura restauração começa a escanear';

  @override
  String get onboardingTorNotePrivacy =>
      'O Tor esconde seu endereço do nó que você consulta — mais lento, e vale a pena.';

  @override
  String get onboardingTorNoteChangeable => 'Pode ser alterado depois em Configurações → Conexões.';

  @override
  String get onboardingPriceNoteRatesOnly =>
      'O serviço de preços recebe apenas pedidos de cotações — nunca endereços ou valores.';

  @override
  String get onboardingPriceNoteTor => 'Roteado pelo Tor por padrão, separado do tráfego da rede.';

  @override
  String get onboardingConnectionNoteServer =>
      'Aponte a Skylight para um servidor de carteira leve (LWS), ou conecte-se ao seu próprio nó Monero.';

  @override
  String get onboardingConnectionNoteChangeable =>
      'Pode ser alterado depois em Configurações → Conexão.';

  @override
  String get onboardingWalletNoteGenerated =>
      'A seed de uma nova carteira é gerada aqui, offline, e mostrada a você uma única vez.';

  @override
  String get onboardingWalletNoteRestore =>
      'A restauração pergunta aproximadamente quando a seed teve fundos pela primeira vez, para pular anos de escaneamento.';

  @override
  String get onboardingWalletCreateBullet1 => 'Uma frase seed Monero, mostrada uma vez';

  @override
  String get onboardingWalletCreateBullet2 => 'Começa vazia, sincroniza a partir de hoje';

  @override
  String get onboardingWalletCreateBullet3 => 'Leva cerca de dois minutos';

  @override
  String get onboardingWalletRestoreBullet1 => 'Uma seed Monero Polyseed, BIP39 ou legada';

  @override
  String get onboardingWalletRestoreBullet2 => 'Data de escaneamento opcional';

  @override
  String get onboardingWalletRestoreBullet3 => 'Recupera seu saldo e histórico existentes';

  @override
  String get onboardingSeedNotePassword =>
      'A Skylight Wallet pede sua senha antes de mostrá-las novamente.';

  @override
  String get onboardingPasswordNoteLaunch =>
      'Pedida a cada abertura, e antes de a seed ser mostrada.';

  @override
  String get onboardingPasswordNoteNotCloud =>
      'Não é uma conta na nuvem. Perdê-la significa restaurar a partir da sua frase seed.';

  @override
  String get onboardingPasswordStrong => 'Forte';

  @override
  String get onboardingPasswordMatch => 'As duas entradas coincidem';

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
  String get unlockPasswordHint => 'Digite sua senha';

  @override
  String get unlockIncorrectPasswordError => 'Senha incorreta. Tente novamente.';

  @override
  String get homeSyncing => 'Sincronizando';

  @override
  String get homeSynced => 'Sincronizado';

  @override
  String get homeTorConnected => 'Tor · conectado';

  @override
  String get homeTorConnecting => 'Tor · conectando';

  @override
  String get homeTorOff => 'Tor · desligado';

  @override
  String get homeReceive => 'Receber';

  @override
  String get homeSend => 'Enviar';

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
  String get receiveQrHint => 'Escaneie este código para enviar Monero para esta carteira.';

  @override
  String get receiveEnlargeQr => 'Toque para ampliar e aumentar o brilho';

  @override
  String get receiveShrinkQr => 'Toque para reduzir';

  @override
  String get receiveShareError => 'Não foi possível abrir a janela de compartilhamento';

  @override
  String receiveAddressHeading(String coin) {
    return 'Seu endereço $coin';
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
  String get settingsExportLogsFailed => 'Não foi possível exportar o arquivo de log';

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
  String get addressBookEdit => 'Editar';

  @override
  String get addressBookContactName => 'Nome do Contato';

  @override
  String get addressBookNameHint => 'Nome';

  @override
  String get addressBookAddDescription => 'Um nome e um endereço Monero para pagá-lo.';

  @override
  String get addressBookEditDescription => 'Atualize o nome ou o endereço deste contato.';

  @override
  String get addressBookUpdate => 'Atualizar';

  @override
  String get addressBookSave => 'Salvar';

  @override
  String get sendPriorityLow => 'Baixa';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'Alta';

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
  String get sendIrreversibleNote =>
      'Transações Monero são irreversíveis. Confira o endereço e o valor antes de enviar.';

  @override
  String get sendSwitchUnit => 'Alternar unidade do valor';

  @override
  String get sendFailedToGetFeesError => 'Não foi possível carregar taxas.';

  @override
  String get torSettingsTitle => 'Configurações do Tor';

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
  String get lwsSetupTorDisabledError => 'O Tor está desativado. Por favor, volte e ative-o.';

  @override
  String get lwsSetupInvalidQrCode => 'Endereço de conexão inválido.';

  @override
  String get advancedSecurityLabel => 'Advanced security';

  @override
  String get advancedSecurityTitle => 'Advanced security';

  @override
  String get advancedSecurityOff => 'Off';

  @override
  String advancedSecurityKeyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keys',
      one: '1 key',
    );
    return '$_temp0';
  }

  @override
  String get securityKeysSection => 'Security keys';

  @override
  String get securityKeysIntroTitle => 'Protect this wallet with a security key';

  @override
  String get securityKeysIntroBody =>
      'Require a YubiKey and its PIN, or the fingerprint on a YubiKey Bio, to open this wallet. Without one of your keys, the wallet file on this phone cannot be decrypted, even by someone who can unlock the phone.';

  @override
  String get securityKeysRequirements =>
      'Works with YubiKey 5 series keys over NFC or USB-C, and with YubiKey Bio over USB-C on Android. On iPhone, USB-C needs YubiKey firmware 5.8 or later. Each key needs a FIDO2 PIN.';

  @override
  String get securityKeysSuggestTwo =>
      'Set up two or more keys and keep one somewhere safe. Your recovery phrase still restores the wallet if you lose them all.';

  @override
  String get securityKeysSetUpButton => 'Set up security keys';

  @override
  String get securityKeysUnavailable =>
      'Security keys need a wallet created or restored with this version of Skylight.';

  @override
  String get securityKeysYourKeys => 'Your keys';

  @override
  String securityKeysAdded(String date) {
    return 'Added $date';
  }

  @override
  String get securityKeysOneKeyWarning =>
      'You have one key. If you lose it, you will need your recovery phrase to open this wallet. Add a second key as a backup.';

  @override
  String get securityKeysAddButton => 'Add a security key';

  @override
  String get securityKeysManageSection => 'Manage';

  @override
  String get securityKeysRemoveTitle => 'Remove a key';

  @override
  String get securityKeysRemoveSubtitle => 'Set up again with only the keys you keep';

  @override
  String get securityKeysRemoveLink => 'Set up';

  @override
  String get securityKeysRemoveExplain =>
      'To remove a key, set up your keys again with only the keys you want to keep. Any key you leave out stops working for this wallet. Have every key you keep with you.';

  @override
  String get securityKeysRemoveConfirm => 'Set up again';

  @override
  String get securityKeysTurnOff => 'Turn off security keys';

  @override
  String get securityKeysTurnOffBody =>
      'The wallet password goes back into this phone\'s secure storage, and the wallet opens without a key.';

  @override
  String get securityKeysTurnOffConfirm => 'Turn off';

  @override
  String get securityKeysTurnedOff => 'Security keys are off';

  @override
  String get securityKeysTurnedOn => 'Security keys are on';

  @override
  String get securityKeysLockSection => 'Lock';

  @override
  String get securityKeysFullLockLabel => 'Fully lock after';

  @override
  String get securityKeysFullLockDescription =>
      'After this long in the background, Skylight closes the wallet and forgets its password. Opening it again needs a security key.';

  @override
  String securityKeysMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String securityKeysHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get securityKeysBackgroundNote =>
      'Background sync keeps working with your view key, which can see incoming payments but cannot spend.';

  @override
  String get securityKeysSetupTitle => 'Set up security keys';

  @override
  String get securityKeysSetupAgainTitle => 'Set up keys again';

  @override
  String get securityKeysSetupAgainNote =>
      'Add only the keys you want to keep. Any key you leave out will no longer open this wallet.';

  @override
  String get securityKeysAddFirst => 'Add your first key';

  @override
  String get securityKeysAddAnother => 'Add another key';

  @override
  String get securityKeysFinish => 'Finish';

  @override
  String get securityKeysOneKeyTitle => 'Finish with one key?';

  @override
  String get securityKeysOneKeyBody =>
      'We suggest two or more. If you lose your only key, you will need your recovery phrase to open this wallet.';

  @override
  String get securityKeysFinishAnyway => 'Finish anyway';

  @override
  String get securityKeysNameLabel => 'Key name';

  @override
  String securityKeysNameDefault(int number) {
    return 'YubiKey $number';
  }

  @override
  String get securityKeysPinLabel => 'Key PIN';

  @override
  String get securityKeysContinue => 'Continue';

  @override
  String get securityKeysNewPinTitle => 'Create a PIN for this key';

  @override
  String get securityKeysNewPinLabel => 'New PIN';

  @override
  String get securityKeysConfirmPinLabel => 'Confirm PIN';

  @override
  String get securityKeysSetPinButton => 'Set PIN';

  @override
  String get securityKeysPinMismatch => 'The PINs do not match.';

  @override
  String securityKeysErrorPinInvalid(int count) {
    return 'Incorrect PIN. $count attempts left before the key locks.';
  }

  @override
  String get securityKeysErrorPinInvalidUnknown => 'Incorrect PIN.';

  @override
  String get securityKeysErrorPinBlocked =>
      'This key\'s PIN is blocked. The key must be reset, which removes it from every wallet it protects.';

  @override
  String get securityKeysErrorPinAuthBlocked =>
      'Too many wrong PINs in a row. Remove the key and connect it again.';

  @override
  String get securityKeysErrorPinPolicy =>
      'The key did not accept that PIN. Some keys need at least 6 characters.';

  @override
  String get securityKeysErrorNotEnrolled => 'This key is not set up for this wallet.';

  @override
  String get securityKeysErrorAlreadyAdded => 'This key is already set up for this wallet.';

  @override
  String securityKeysErrorUnsupported(String reason) {
    return 'This key cannot be used here: $reason';
  }

  @override
  String get securityKeysErrorTimeout => 'No key was found. Try again.';

  @override
  String get securityKeysErrorTransport => 'The connection to the key was lost. Try again.';

  @override
  String securityKeysErrorGeneric(String reason) {
    return 'Something went wrong: $reason';
  }

  @override
  String get securityKeyUnlockTitle => 'Unlock with your security key';

  @override
  String get securityKeyUnlockButton => 'Unlock';

  @override
  String get securityKeyLostKeys => 'Lost your keys?';

  @override
  String get securityKeyLostKeysBody =>
      'Your recovery phrase can open this wallet. Then set up new keys in Settings.';

  @override
  String get securityKeyUseRecoveryPhrase => 'Use recovery phrase';

  @override
  String get securityKeyRecoveryPhraseHint => 'Enter your recovery phrase';

  @override
  String get securityKeyRecoveryWrongPhrase => 'That recovery phrase is not this wallet\'s.';

  @override
  String get securityKeyRecoveryNotPossible =>
      'This wallet came from a 25-word seed, so its phrase cannot open it here. Delete the wallet and restore it from the phrase.';

  @override
  String get securityKeyRecoveredToast =>
      'Unlocked with your recovery phrase. Set up your keys again in Settings.';

  @override
  String get securityKeyConnectTitle => 'Connect your security key';

  @override
  String get securityKeyConnectBodyAndroid =>
      'Plug your YubiKey into the USB-C port and touch it when it blinks, or hold it flat against the back of your phone.';

  @override
  String get securityKeyConnectBodyIos =>
      'Hold your YubiKey near the top of your iPhone, or plug it in and touch it when it blinks.';

  @override
  String get securityKeyConnectButton => 'Connect key';

  @override
  String get securityKeyTryAgain => 'Try again';

  @override
  String get securityKeyWaiting => 'Waiting for your key…';

  @override
  String get securityKeyTalkingToKey => 'Talking to your key…';

  @override
  String get securityKeyKeyBlinking => 'Your key is blinking';

  @override
  String get securityKeyTouchToSelect => 'Touch your key';

  @override
  String get securityKeyTouchBody => 'Touch the gold contact on your key while it blinks.';

  @override
  String get securityKeyPinTitle => 'Enter your key\'s PIN';

  @override
  String get securityKeyPinBody =>
      'The PIN you set for this YubiKey. It is not your phone\'s passcode.';

  @override
  String securityKeyPinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left before the key locks.',
      one: '1 attempt left before the key locks.',
    );
    return '$_temp0';
  }

  @override
  String get securityKeyUseAnotherKey => 'Use a different key';

  @override
  String get securityKeyUseFingerprint => 'Use fingerprint instead';

  @override
  String get securityKeyUsePin => 'Use PIN instead';

  @override
  String securityKeysNewPinBodyCount(int count) {
    return 'This key has no PIN yet. Choose one with at least $count characters. Skylight requires it, so a key found by someone else cannot open your wallet.';
  }

  @override
  String securityKeysPinTooShortCount(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get securityKeyCheckingPin => 'Checking your PIN…';

  @override
  String get securityKeyWorking => 'One moment…';

  @override
  String get securityKeyKeepHolding => 'Keep your key against the phone.';

  @override
  String get securityKeyHoldAgain => 'Hold your key to your phone again';

  @override
  String get securityKeyConnectAgain => 'Connect your key again';

  @override
  String get securityKeyTouchToConfirm => 'Touch your key to confirm';

  @override
  String get securityKeyTouchOnceMore => 'Touch your key once more';

  @override
  String get securityKeyTouchToUnlock => 'Touch your key to unlock';

  @override
  String get securityKeyFingerprintToConfirm => 'Touch the fingerprint sensor';

  @override
  String get securityKeyFingerprintOnceMore => 'Touch the sensor once more';

  @override
  String get securityKeyFingerprintToUnlock => 'Touch the sensor to unlock';

  @override
  String get securityKeyFingerprintBody => 'Use a finger you enrolled on this YubiKey Bio.';

  @override
  String securityKeyTouchCount(int current, int total) {
    return 'Touch $current of $total';
  }

  @override
  String get securityKeyAddedTitle => 'Key added';

  @override
  String get securityKeyNameBody => 'Give it a name so you can tell your keys apart.';

  @override
  String get securityKeySaveName => 'Save';

  @override
  String get securityKeysErrorKeyUnsupported =>
      'This key cannot protect a wallet. Use a YubiKey 5 series key or a YubiKey Bio.';

  @override
  String get securityKeysErrorPinChangeRequired =>
      'This key wants a new PIN first. Change it in the Yubico Authenticator app, then try again.';

  @override
  String securityKeysErrorUvInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fingerprint not recognized. $count tries left.',
      one: 'Fingerprint not recognized. 1 try left.',
    );
    return '$_temp0';
  }

  @override
  String get securityKeysErrorUvInvalidUnknown => 'Fingerprint not recognized.';

  @override
  String get securityKeysErrorUvBlocked =>
      'The fingerprint reader on this key is locked. Enter the key\'s PIN instead.';

  @override
  String get securityKeysErrorUvNotConfigured =>
      'This key has no fingerprint set up. Enter its PIN instead.';

  @override
  String securityKeyPinTitleNamed(String name) {
    return 'Enter the PIN for $name';
  }

  @override
  String securityKeysSerial(String serial) {
    return 'Serial $serial';
  }

  @override
  String get securityKeysErrorDifferentKey =>
      'That is a different key from the one you touched. Start again with the key you want to use.';
}
