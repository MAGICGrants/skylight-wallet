part of 'ethereum_chain_wallet.dart';

/// An ERC-20 token on an EVM chain. Shares the parent chain coin's address
/// (same derivation) and connection (its RPC + explorer), so it has no setup of
/// its own. Balance comes from `balanceOf`, sends are a `transfer(to,amount)`
/// call to the token contract, and the **fee is paid in the chain's native coin
/// (ETH), not the token**.
class Erc20ChainWallet extends EthereumChainWallet {
  Erc20ChainWallet({
    required super.chainId,
    required super.coinSymbol,
    required super.coinName,
    required super.iconAsset,
    required super.isTestnet,
    required this.tokenContractAddress,
    required this.tokenDecimals,
    required this.parentCoinSymbol,
    int displayDecimals = 6,
    int displaySmallerDigits = 2,
  }) : _displayDecimals = displayDecimals,
       _displaySmallerDigits = displaySmallerDigits,
       super(connectionAddressExample: '');

  final String tokenContractAddress;
  final int tokenDecimals;
  final String parentCoinSymbol;
  final int _displayDecimals;
  final int _displaySmallerDigits;

  late final BigInt _tokenUnit = BigInt.from(10).pow(tokenDecimals);
  BigInt _tokenBalanceRaw = BigInt.zero;

  double get _tokenBalance => _tokenBalanceRaw.toDouble() / _tokenUnit.toDouble();

  // ----- Metadata / connection reuse -----

  @override
  int get decimals => _displayDecimals;
  @override
  int get smallerDigits => _displaySmallerDigits;

  @override
  String get feeCoinSymbol => parentCoinSymbol;
  @override
  int get feeDecimals => 10; // native ETH display precision
  @override
  String get feeIconAsset =>
      isTestnet ? 'assets/icons/ethereum_sepolia.svg' : 'assets/icons/ethereum.svg';

  // The token has its own RPC/explorer setup screens (like any coin), but the
  // config is shared with the parent chain coin's namespace, so setting it from
  // either the token or the parent works and never needs entering twice.
  @override
  String get connectionPrefSymbol => parentCoinSymbol;

  @override
  BigInt get txAmountUnit => _tokenUnit;
  @override
  BigInt get fallbackGasLimit => BigInt.from(100000);

  // ----- Balance -----

  @override
  Future<void> refresh() async {
    // Native ETH balance (for gas) + receipt polling.
    await super.refresh();
    if (!_connected || _address == null) return;
    try {
      final hex = await _rpc.ethCall(tokenContractAddress, erc20BalanceOfData(_address!));
      _tokenBalanceRaw = _parseHexBig(hex);
    } catch (e) {
      walletLog(LogLevel.warn, 'token balanceOf failed: $e');
    }
  }

  @override
  Future<void> loadTotalBalance() async {
    if (!_connected) return;
    setTotalBalance(_tokenBalance);
  }

  @override
  Future<void> loadUnlockedBalance() async {
    if (!_connected) return;
    setUnlockedBalance(_tokenBalance);
  }

  // ----- History -----

  @override
  Future<List<ExplorerTx>> fetchExplorerTransfers(int? socksPort) => _explorer.fetchTokenTransfers(
    explorerAddress,
    _address!,
    tokenContractAddress,
    socksPort: socksPort,
  );

  // ----- Send -----

  @override
  Future<PendingTransaction> createTx(
    String destinationAddress,
    double amount,
    String? amountText,
    bool isSweepAll, {
    int priority = 0,
  }) async {
    if (_mnemonic == null || _address == null) throw Exception('Wallet is not loaded.');
    if (!_rpc.isConfigured) throw Exception('Not connected to an RPC endpoint.');
    if (!isAddressValid(destinationAddress)) throw Exception('Invalid Ethereum address.');
    final from = _address!;

    final rawAmount = isSweepAll
        ? _tokenBalanceRaw
        : amountText != null
        ? decimalToBaseUnits(amountText, tokenDecimals)
        : BigInt.from((amount * _tokenUnit.toDouble()).round());
    if (rawAmount <= BigInt.zero || rawAmount > _tokenBalanceRaw) {
      throw Exception('Unlocked funds too low');
    }

    // EIP-1559 (type-2) call to the token contract: value 0, transfer in data.
    final dataHex = erc20TransferData(destinationAddress, rawAmount);
    final inputs = await _resolveFeeInputs(from, tokenContractAddress, data: dataHex);
    final tip = _scaleTip(inputs.tipBase, priority);
    final maxFeePerGas = inputs.baseFee * BigInt.two + tip;
    final maxFeeTotal = inputs.gasLimit * maxFeePerGas;
    // Gas is paid in native ETH, separate from the token balance.
    if (maxFeeTotal > _balanceWei) {
      walletLog(LogLevel.info, 'insufficient gas: fee $maxFeeTotal > eth $_balanceWei');
      throw Exception('Insufficient gas funds');
    }

    final Uint8List signed;
    try {
      final credentials = await _credentials();
      final tx = Transaction(
        from: credentials.address,
        to: EthereumAddress.fromHex(tokenContractAddress),
        value: EtherAmount.zero(),
        maxGas: inputs.gasLimit.toInt(),
        maxPriorityFeePerGas: EtherAmount.inWei(tip),
        maxFeePerGas: EtherAmount.inWei(maxFeePerGas),
        nonce: inputs.nonce,
        data: hexToBytes(dataHex),
      );
      signed = await Web3Client(
        _rpc.url!,
        http.Client(),
      ).signTransaction(credentials, tx, chainId: chainId);
    } catch (e) {
      walletLog(LogLevel.warn, 'erc20 build/sign failed: $e');
      rethrow;
    }

    final raw = (signed.isNotEmpty && signed[0] >= 0xc0)
        ? Uint8List.fromList([0x02, ...signed])
        : signed;

    return EthereumPendingTx(
      amount: rawAmount.toDouble() / _tokenUnit.toDouble(),
      fee: maxFeeTotal.toDouble() / EthereumChainWallet._weiPerEth.toDouble(),
      valueWei: rawAmount, // token raw; readTxHistory divides by txAmountUnit
      feeWei: maxFeeTotal,
      rawHex: '0x${bytesToHex(raw)}',
      txHash: '0x${bytesToHex(keccak256(raw))}',
      to: destinationAddress,
    );
  }

  @override
  Future<void> deleteFiles() async {
    await super.deleteFiles();
    _tokenBalanceRaw = BigInt.zero;
  }

  static BigInt _parseHexBig(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.isEmpty) return BigInt.zero;
    return BigInt.parse(clean, radix: 16);
  }
}
