// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

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
  String get lwsSetupDescription =>
      'Conecte-se a um servidor light-wallet Monero (LWS) ou ao seu próprio nó completo. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você. Com um LWS, sua chave privada de visualização e seu endereço primário serão compartilhados com este servidor.';

  @override
  String get lwsSetupProxyPortLabel => 'Porta do Proxy HTTP (Opcional)';

  @override
  String get lwsSetupProxyPortHint => '4444 para I2P';

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
  String get fiatApiSetupDescription =>
      'A Skylight Wallet pode buscar automaticamente o preço mais recente do Monero. Seus saldos não são enviados ao servidor. Como você quer buscar esses dados de preço?';

  @override
  String get createWalletDescription =>
      'Você quer criar uma nova carteira ou restaurar uma carteira existente?';

  @override
  String get createWalletRestoreExistingDesc => 'Insira uma frase de recuperação Monero existente';

  @override
  String get createWalletCreateNewDesc =>
      'A Skylight Wallet gera uma nova frase de recuperação Polyseed';

  @override
  String get generateSeedSubtitleCovered =>
      'Estas palavras, nesta ordem, são a sua carteira. Anote-as e guarde-as em um cofre físico. Se você perder estas palavras ou compartilhá-las com outra pessoa, perderá seu dinheiro permanentemente. Um planejamento cuidadoso agora evita um possível desastre depois.';

  @override
  String get onboardingConnectionNoteServer =>
      'Use um servidor light-wallet (LWS) ou seu próprio nó Monero.';

  @override
  String get onboardingConnectionNoteChangeable =>
      'Você pode alterar isso depois nas Configurações.';

  @override
  String get lwsDetailsTitle => 'Detalhes da Carteira';

  @override
  String get lwsDetailsPrimaryAddressLabel => 'Endereço Primário';

  @override
  String get lwsDetailsSecretViewKeyLabel => 'Chave Privada de Visualização';

  @override
  String get lwsDetailsRestoreHeightLabel => 'Bloco de Restauração';

  @override
  String get restoreWalletDescription =>
      'Insira sua frase de recuperação Monero abaixo. Verificaremos os formatos comuns.';

  @override
  String get restoreScanDescription =>
      'A Skylight Wallet pode ignorar o histórico irrelevante para economizar seu tempo. Escolha o primeiro mês em que você usou a carteira ou selecione Não tenho certeza para verificar tudo. Não há problema em escolher um mês muito antigo, mas é ruim escolher um mês muito recente.';

  @override
  String get restoreWalletInvalidMnemonic => 'Frase de recuperação inválida.';

  @override
  String get restoreWalletSeedTypePolyseed => 'Polyseed';

  @override
  String get restoreWalletSeedTypeBip39 => 'BIP39';

  @override
  String get restoreWalletSeedTypeLegacy => 'Legado';

  @override
  String get navigationBarWallet => 'Carteira';

  @override
  String get historyFilterAddress => 'Endereço';

  @override
  String get historyFilterAddressAny => 'Qualquer Endereço';

  @override
  String get historyFilterAddressHint =>
      'Transações recebidas neste endereço ou enviadas para ele.';

  @override
  String get historyFilterAddressInvalid => 'Não é um endereço Monero';

  @override
  String get unlockTitle => 'Desbloquear Carteira';

  @override
  String get homeDisconnected => 'Desconectado';

  @override
  String get receiveQrHint => 'Escaneie este código para enviar Monero para esta carteira.';

  @override
  String get sendInvalidAddressError => 'Endereço inválido.';

  @override
  String get syncFrequencySheetSubtitle =>
      'Com que frequência o Monero sincroniza enquanto o app está fechado.';

  @override
  String get syncFrequencyContinuousDesc =>
      'Sincroniza o Monero continuamente em segundo plano para que esteja sempre atualizado ao abrir o app. Usa mais bateria e exige uma notificação persistente.';

  @override
  String get syncFrequencyPeriodicDesc =>
      'Sincroniza o Monero periodicamente em segundo plano para que geralmente esteja atualizado ao abrir o app. Com um nó Monero, só sincroniza enquanto carrega e no WiFi.';

  @override
  String get syncFrequencyPeriodicDescIos =>
      'Sincroniza o Monero periodicamente em segundo plano para que geralmente esteja atualizado ao abrir o app. Com um nó Monero, só sincroniza enquanto carrega.';

  @override
  String get settingsThemeLightDesc => 'Claro e limpo';

  @override
  String get settingsLwsViewKeysLabel => 'Chaves de Visualização do LWS';

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
  String get secretKeysTitle => 'Chaves Privadas de Restauração';

  @override
  String get secretKeysDescription =>
      'Estas frases de recuperação e chaves restauram o controle total da sua carteira. Qualquer pessoa que as veja pode gastar seus fundos.';

  @override
  String get secretKeysMnemonic => 'Frase de Recuperação';

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
  String get addressBookAddDescription => 'Um nome e um endereço Monero para pagá-lo.';

  @override
  String get addressBookEditDescription => 'Atualize o nome ou o endereço deste contato.';

  @override
  String get sendIrreversibleNote =>
      'As transações são irreversíveis, então verifique se o endereço e o valor estão corretos.';

  @override
  String get torChoiceSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. De modo geral, como você quer que a Skylight Wallet lide com as conexões Tor?';

  @override
  String get torSettingsSheetSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. Alterar isto reconecta sua carteira.';
}
