const String walletFileName = 'mywallet';
const String torDataDirName = 'tor';
const int txDirectionIncoming = 0;
const int txDirectionOutgoing = 1;
const supportedFiatCurrencies = [
  'USD',
  'EUR',
  'CAD',
  'AUD',
  'GBP',
  'CHF',
  'JPY',
];
const indirectPairCurrencies = ['CAD', 'AUD', 'GBP', 'CHF', 'JPY'];
const currencySymbols = {
  'USD': '\$',
  'EUR': '€',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'GBP': '£',
  'CHF': 'Fr',
  'JPY': '¥',
};
const walletPasswordStorageKey = 'walletPassword';
