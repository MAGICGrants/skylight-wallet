const String torDataDirName = 'tor';
const int txDirectionIncoming = 0;
const int txDirectionOutgoing = 1;
// Transaction types for the future liquidity-pool / swap feature (Serai). No
// data carries these yet; the history Type filter lists them ahead of it.
const int txTypeBridge = 2;
const int txTypeSwap = 3;
const int txTypeAdd = 4;
const int txTypeRemove = 5;
const supportedFiatCurrencies = ['USD', 'EUR', 'CAD', 'AUD', 'GBP', 'CHF', 'JPY'];
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
