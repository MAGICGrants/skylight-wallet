// The whole logger lives in wallet-core (wallet_infra, D25): the log() API +
// formatter, the verbose gate, the file sink (FileLogSink), log rotation
// (cleanOldLogFiles), and file listing/export. The app only installs the sink
// (console + file) in wallet_core_glue.dart.
export 'package:wallet_infra/wallet_infra.dart'
    show LogLevel, log, LogFileInfo, getLogFiles, exportLogFiles, cleanOldLogFiles;
