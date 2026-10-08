import CoreNFC
import CryptoKit
import CryptoTokenKit
import ExternalAccessory
import Foundation
import YubiKit

// FIDO2 security-key operations for FHSE (vtnerd/fhse) wallet-file encryption.
//
// FHSE needs a non-discoverable credential created with the hmac-secret
// extension under a non-web relying-party id ("fhse:encryption"), and later a
// raw CTAP2 getAssertion that returns the 32-byte hmac-secret output. Platform
// passkey APIs cannot do that (domain rpIds, hashed PRF salts), so this talks
// CTAP2 directly through YubiKit's CTAP2.Session. User verification is the
// key's PIN or its built-in UV (a YubiKey Bio fingerprint): credProtect level 3
// at creation and a fresh PIN/UV token for every makeCredential/getAssertion.
// Tokens are never kept beyond one call. Both kinds of token set CTAP's UV
// flag, so the hmac-secret output is the same whichever one was used.
//
// Before CTAP2, the YubiKey serial number is read from the Management
// application on the same connection. That tells the UI which registered key
// is connected, and lets a request refuse a different key before a PIN or UV
// token request reaches it (credProtect 3 hides credentials until then).
//
// This file has no Flutter types; SecurityKeyChannel.swift maps it to the
// method channel. Nothing here logs PINs, salts, user ids, credential ids,
// serial numbers or hmac-secret outputs, and YubiKit's own logging is capped
// at warnings (its debug level can print credential ids).

// MARK: - Results and errors

enum SecurityKeyTransport: String, Sendable {
  case nfc
  case usb
  case lightning

  /// Plugged in (USB-C or Lightning), so a touch is a separate step. Holding
  /// a key to NFC already shows the user is there.
  var isWired: Bool { self != .nfc }
}

/// How the user is verified for enroll and getHmacSecret.
enum SecurityKeyVerification: Sendable {
  /// The key's PIN.
  case pin(String)
  /// The key's built-in user verification (a YubiKey Bio fingerprint).
  case uv

  var usesBuiltInUV: Bool {
    if case .uv = self { return true }
    return false
  }
}

/// Progress for the UI while a request runs. Never carries secrets.
enum SecurityKeyStatus: String, Sendable {
  case waitingForKey
  case keyConnected
  case processing
  case touchNeeded
  case fingerprintNeeded
}

/// Hears one request's progress, with the key's transport once connected.
/// Called on the operations actor; it must hand off to its own thread.
typealias SecurityKeyStatusHandler = @Sendable (SecurityKeyStatus, SecurityKeyTransport?) -> Void

struct SecurityKeyCapabilities: Sendable {
  let nfc: Bool
  let usb: Bool
}

struct SecurityKeyInfo: Sendable {
  let pinSet: Bool
  let pinRetries: Int?
  let hmacSecret: Bool
  let credProtect: Bool
  let aaguid: Data?
  let versions: [String]
  let transport: SecurityKeyTransport
  /// YubiKey serial number; nil when hidden, not a YubiKey, or unreadable.
  let serial: Int?
  /// Built-in UV present and configured (options.uv == true).
  let uv: Bool
  /// Built-in UV present at all, configured or not (options lists uv).
  let uvSupported: Bool
  /// Only when `uv`: UV retries left, nil if the key would not say.
  let uvRetries: Int?
  /// options.pinUvAuthToken == true; the UV path needs it.
  let pinUvAuthToken: Bool
  let minPinLength: Int
  let forcePinChange: Bool
  /// The key was touched for authenticatorSelection.
  let touched: Bool
}

/// The credential used and its 32-byte hmac-secret output. A class so the
/// output has a single owner that can zero it in place once it is delivered
/// (wiping a copy of a Data value would only zero the copy).
final class SecurityKeySecret: @unchecked Sendable {
  let credentialId: Data
  /// Serial number of the key that did the work, when it would say.
  let serial: Int?
  private var hmacSecret: Data
  private let lock = NSLock()

  init(credentialId: Data, serial: Int?, hmacSecret: Data) {
    self.credentialId = credentialId
    self.serial = serial
    self.hmacSecret = hmacSecret
  }

  /// Gives `body` the output; copy out what is needed, do not keep it.
  func withHmacSecret<R>(_ body: (Data) throws -> R) rethrows -> R {
    try lock.withLock { try body(hmacSecret) }
  }

  func wipe() {
    lock.withLock { hmacSecret.wipe() }
  }

  deinit {
    hmacSecret.wipe()
  }
}

/// Every failure leaves this file as one of these; `code` is the channel's
/// error code and `message` is calm, user-presentable copy (it is also what
/// the NFC sheet shows when the session closes with an error).
struct SecurityKeyError: Error, LocalizedError, Sendable {
  enum Code: String, Sendable {
    case cancelled
    case timeout
    case busy
    case pinNotSet
    case pinAlreadySet
    case pinInvalid
    case pinBlocked
    case pinAuthBlocked
    case pinPolicy
    case pinChangeRequired
    case differentKey
    case uvInvalid
    case uvBlocked
    case uvNotConfigured
    case noCredentials
    case credentialExcluded
    case unsupported
    case transport
    case unknown
  }

  let code: Code
  let message: String
  /// Only for `pinInvalid` and `uvInvalid`: PIN or UV retries left, when the
  /// key would say.
  let retries: Int?

  init(_ code: Code, _ message: String, retries: Int? = nil) {
    self.code = code
    self.message = message
    self.retries = retries
  }

  var errorDescription: String? { message }

  static let cancelled = SecurityKeyError(.cancelled, "Cancelled.")
  static let timeout = SecurityKeyError(.timeout, "No security key was found in time.")
  static let busy = SecurityKeyError(.busy, "Another security key request is still running.")
  static let pinNotSet = SecurityKeyError(.pinNotSet, "This security key has no PIN yet.")
  static let pinAlreadySet = SecurityKeyError(.pinAlreadySet, "This security key already has a PIN.")
  static let pinChangeRequired = SecurityKeyError(
    .pinChangeRequired, "This security key needs a new PIN before it can be used.")
  static let differentKey = SecurityKeyError(
    .differentKey, "This is a different security key from the one you chose.")
  static let uvBlocked = SecurityKeyError(
    .uvBlocked, "Fingerprint unlock is locked on this security key. Use its PIN instead.")
  static let noCredentials = SecurityKeyError(
    .noCredentials, "This security key does not hold the key for this wallet.")

  static func unsupported(_ message: String) -> SecurityKeyError {
    SecurityKeyError(.unsupported, message)
  }

  static func unknown(_ message: String) -> SecurityKeyError {
    SecurityKeyError(.unknown, message)
  }
}

// MARK: - Operations

actor SecurityKeyOperations {
  /// How long to wait for a key to be tapped or plugged in.
  static let connectTimeout: Duration = .seconds(60)

  /// FHSE's libfido2 code signs over clientdata {0x01}; CTAP gets its SHA-256.
  static let clientDataHash = Data(SHA256.hash(data: Data([0x01])))

  static let userName = "FHSE Encryption"
  static let saltLength = 32
  static let maxUserIdLength = 64
  static let defaultMaxCredentialCountInList = 8
  /// CTAP 2.1's minimum when getInfo does not report minPINLength.
  static let defaultMinPinLength = 4

  private static let holdMessage = "Keep holding your key…"
  private static let doneMessage = "Done."

  private static let configureLogging: Void = {
    // YubiKit logs credential ids at debug level; keep it to warnings.
    Logs.configure(logLevel: .warning)
  }()

  private var isRunning = false
  private var cancelRequested = false

  // Connection phase. The generation keeps a late result or a stale timer
  // from one request from touching the next one.
  private var connectGeneration = 0
  private var connectWaiter: CheckedContinuation<KeyLink, Error>?
  private var connectTask: Task<Void, Never>?
  private var connectTimer: Task<Void, Never>?

  // Set while the key waits for a touch, so cancel() can abort it on the key.
  private var ctapCancel: (@Sendable () async -> Void)?

  // Per request: who hears about progress, the transport once a key is
  // connected, and whether a wait on the key is for a fingerprint.
  private var onStatus: SecurityKeyStatusHandler?
  private var statusTransport: SecurityKeyTransport?
  private var usesBuiltInUV = false

  init() {
    _ = Self.configureLogging
  }

  // MARK: Capabilities

  nonisolated static func capabilities() -> SecurityKeyCapabilities {
    #if targetEnvironment(simulator)
    return SecurityKeyCapabilities(nfc: false, usb: false)
    #else
    // USB-C keys use CryptoTokenKit (needs the smart card entitlement);
    // Lightning devices use the YubiKey 5Ci over External Accessory.
    let usb = TKSmartCardSlotManager.default != nil || DeviceModel.hasLightningPort
    return SecurityKeyCapabilities(nfc: NFCTagReaderSession.readingAvailable, usb: usb)
    #endif
  }

  // MARK: Public operations

  /// Reads the key's capabilities. With `touch`, a wired key is also asked for
  /// a touch (authenticatorSelection) so the user confirms which key it is.
  func inspect(
    prompt: String,
    touch: Bool,
    onStatus: @escaping SecurityKeyStatusHandler
  ) async throws -> SecurityKeyInfo {
    try await withKey(prompt: prompt, onStatus: onStatus) { session, link, serial in
      let info = try await session.getInfo()
      try checkCancelled()
      let pinProtocol = Self.pinProtocol(for: info)
      let pinSet = info.options.clientPin == true
      var pinRetries: Int?
      if pinSet {
        pinRetries = try? await session.getPinRetries(protocol: pinProtocol).retries
      }
      let uv = info.options.userVerification == true
      var uvRetries: Int?
      if uv {
        uvRetries = try? await session.getUVRetries(protocol: pinProtocol)
      }
      try checkCancelled()

      // Last, so the answer follows the touch straight away.
      var touched = false
      if touch, link.transport.isWired {
        touched = try await touchToSelect(session, info: info)
      }
      return SecurityKeyInfo(
        pinSet: pinSet,
        pinRetries: pinRetries,
        hmacSecret: info.extensions.contains(.hmacSecret),
        credProtect: info.extensions.contains(.credProtect),
        aaguid: info.aaguid.rawValue,
        versions: info.versions.map(Self.versionString),
        transport: link.transport,
        serial: serial,
        uv: uv,
        uvSupported: info.options.userVerification != nil,
        uvRetries: uvRetries,
        pinUvAuthToken: info.options.pinUVAuthToken == true,
        minPinLength: info.minPinLength.map { Int($0) } ?? Self.defaultMinPinLength,
        forcePinChange: info.forcePinChange == true,
        touched: touched
      )
    }
  }

  func setPin(
    newPin: String,
    expectSerial: Int?,
    prompt: String,
    onStatus: @escaping SecurityKeyStatusHandler
  ) async throws {
    guard !newPin.isEmpty else { throw SecurityKeyError(.pinPolicy, "The PIN is empty.") }
    try await withKey(
      prompt: prompt, expectSerial: expectSerial, onStatus: onStatus
    ) { session, _, _ in
      let info = try await session.getInfo()
      guard let clientPin = info.options.clientPin else {
        throw SecurityKeyError.unsupported("This security key does not support a PIN.")
      }
      if clientPin { throw SecurityKeyError.pinAlreadySet }
      let length = newPin.precomposedStringWithCanonicalMapping.unicodeScalars.count
      if let minLength = info.minPinLength, length < Int(minLength) {
        throw SecurityKeyError(.pinPolicy, "The PIN must be at least \(minLength) characters.")
      }
      try checkCancelled()
      do {
        try await session.setPin(newPin, protocol: Self.pinProtocol(for: info))
      } catch CTAP2.SessionError.illegalArgument {
        // YubiKit's own length checks (4 code points, 63 UTF-8 bytes).
        throw SecurityKeyError(.pinPolicy, "The PIN must be 4 to 63 characters.")
      } catch CTAP2.SessionError.ctapError(.notAllowed, _) {
        throw SecurityKeyError.pinAlreadySet
      }
    }
  }

  func enroll(
    rpId: String,
    userId: Data,
    salt: Data,
    verification: SecurityKeyVerification,
    excludeCredentialIds: [Data],
    expectSerial: Int?,
    prompt: String,
    onStatus: @escaping SecurityKeyStatusHandler
  ) async throws -> SecurityKeySecret {
    try Self.validate(rpId: rpId, salt: salt, verification: verification)
    guard (1...Self.maxUserIdLength).contains(userId.count) else {
      throw SecurityKeyError.unknown("Invalid argument: userId must be 1 to 64 bytes.")
    }

    return try await withKey(
      prompt: prompt, builtInUV: verification.usesBuiltInUV, expectSerial: expectSerial,
      onStatus: onStatus
    ) { session, link, serial in
      // a. Capabilities.
      let info = try await session.getInfo()
      let missing = [CTAP2.Extension.Identifier.hmacSecret, .credProtect]
        .filter { !info.extensions.contains($0) }
        .map(\.value)
      guard missing.isEmpty else {
        throw SecurityKeyError.unsupported(
          "This security key does not support \(missing.joined(separator: " or ")).")
      }
      try Self.requireUsable(info, for: verification)
      // b. PIN/UV auth protocol.
      let pinProtocol = Self.pinProtocol(for: info)
      try checkCancelled()

      // c. PIN/UV token for makeCredential (and getAssertion), bound to rpId.
      let createToken = try await authToken(
        session, verification, permissions: [.makeCredential, .getAssertion], rpId: rpId,
        protocol: pinProtocol)
      try checkCancelled()

      // d. makeCredential: non-discoverable, hmac-secret, credProtect 3.
      let credProtect = try await CTAP2.Extension.CredProtect(
        level: .userVerificationRequired, session: session, enforce: true)
      let hmacSecret = CTAP2.Extension.HmacSecret()
      let parameters = CTAP2.MakeCredential.Parameters(
        clientDataHash: Self.clientDataHash,
        rp: WebAuthn.RelyingParty(id: rpId, name: rpId),
        user: WebAuthn.User(id: userId, name: Self.userName, displayName: Self.userName),
        pubKeyCredParams: [.es256],
        excludeList: excludeCredentialIds.isEmpty
          ? nil : excludeCredentialIds.map { WebAuthn.CredentialDescriptor(id: $0) },
        extensions: [hmacSecret.makeCredential.input(), credProtect.input()],
        rk: false
      )
      let created = try await finish(
        await session.makeCredential(parameters: parameters, token: createToken))

      guard credProtect.output(from: created) == .userVerificationRequired else {
        throw SecurityKeyError.unsupported("credProtect not applied")
      }
      guard (try? hmacSecret.makeCredential.output(from: created)) == .enabled else {
        throw SecurityKeyError.unsupported("hmac-secret not enabled on the new credential")
      }
      guard let credentialId = created.authenticatorData.attestedCredentialData?.credentialId,
        !credentialId.isEmpty
      else {
        throw SecurityKeyError.unknown("The security key did not return a credential id.")
      }
      try checkCancelled()
      await link.setStatus(Self.holdMessage)

      // e. Fresh token: CTAP 2.1 drops mc/ga permissions after makeCredential.
      let assertToken = try await authToken(
        session, verification, permissions: [.getAssertion], rpId: rpId, protocol: pinProtocol)
      try checkCancelled()

      // f. getAssertion with one hmac-secret salt.
      return try await assertHmacSecret(
        session, rpId: rpId, salt: salt, allowList: [credentialId], token: assertToken,
        serial: serial)
    }
  }

  func getHmacSecret(
    rpId: String,
    salt: Data,
    verification: SecurityKeyVerification,
    credentialIds: [Data],
    expectSerial: Int?,
    prompt: String,
    onStatus: @escaping SecurityKeyStatusHandler
  ) async throws -> SecurityKeySecret {
    try Self.validate(rpId: rpId, salt: salt, verification: verification)
    let credentialIds = credentialIds.filter { !$0.isEmpty }
    guard !credentialIds.isEmpty else { throw SecurityKeyError.noCredentials }

    return try await withKey(
      prompt: prompt, builtInUV: verification.usesBuiltInUV, expectSerial: expectSerial,
      onStatus: onStatus
    ) { session, _, serial in
      let info = try await session.getInfo()
      guard info.extensions.contains(.hmacSecret) else {
        throw SecurityKeyError.unsupported("This security key does not support hmac-secret.")
      }
      try Self.requireUsable(info, for: verification)
      let pinProtocol = Self.pinProtocol(for: info)
      let batchSize = max(
        1, Int(info.maxCredentialCountInList ?? UInt(Self.defaultMaxCredentialCountInList)))

      for start in stride(from: 0, to: credentialIds.count, by: batchSize) {
        let batch = Array(credentialIds[start..<min(start + batchSize, credentialIds.count)])
        try checkCancelled()
        // A fresh token per attempt, so a failed batch cannot leave it spent
        // (with built-in UV that is one fingerprint per batch).
        let token = try await authToken(
          session, verification, permissions: [.getAssertion], rpId: rpId, protocol: pinProtocol)
        try checkCancelled()
        do {
          return try await assertHmacSecret(
            session, rpId: rpId, salt: salt, allowList: batch, token: token, serial: serial)
        } catch CTAP2.SessionError.ctapError(.noCredentials, _) {
          continue
        }
      }
      throw SecurityKeyError.noCredentials
    }
  }

  /// Cancels whatever is in flight; that request then fails with `cancelled`.
  func cancel() async {
    guard isRunning else { return }
    cancelRequested = true
    abandonConnect(with: .cancelled)
    if let ctapCancel {
      await ctapCancel()
    }
  }

  // MARK: Request lifecycle

  /// Waits for a key, reads its serial number, opens a CTAP2 session, runs
  /// `body` with the serial, then closes the connection (with a success or
  /// failure message on the NFC sheet). With `expectSerial`, a key reporting
  /// a different serial fails with `differentKey` before `body` runs, so
  /// before any PIN or UV token request. `onStatus` hears this request's
  /// progress until it returns; with `builtInUV` a wait on the key is
  /// reported as a fingerprint.
  private func withKey<T: Sendable>(
    prompt: String,
    builtInUV: Bool = false,
    expectSerial: Int? = nil,
    onStatus: @escaping SecurityKeyStatusHandler,
    _ body: (CTAP2.Session, KeyLink, Int?) async throws -> T
  ) async throws -> T {
    guard !isRunning else { throw SecurityKeyError.busy }
    isRunning = true
    cancelRequested = false
    self.onStatus = onStatus
    statusTransport = nil
    usesBuiltInUV = builtInUV
    defer {
      isRunning = false
      ctapCancel = nil
      self.onStatus = nil
      statusTransport = nil
      usesBuiltInUV = false
    }

    report(.waitingForKey)
    let link = try await connect(prompt: prompt)
    statusTransport = link.transport
    report(.keyConnected)
    do {
      try checkCancelled()
      await link.setStatus(Self.holdMessage)
      // A key that hides its serial (or is not a YubiKey) is let through.
      let serial = await Self.readSerial(link.connection)
      try checkCancelled()
      if let expectSerial, let serial, serial != expectSerial {
        throw SecurityKeyError.differentKey
      }
      let session: CTAP2.Session
      do {
        session = try await CTAP2.Session.makeSession(connection: link.connection)
      } catch CTAP2.SessionError.featureNotSupported {
        // FIDO over USB CCID needs YubiKey firmware 5.8 or later.
        throw SecurityKeyError.unsupported(
          link.transport == .usb
            ? "This security key cannot use FIDO2 over USB-C on this device (that needs firmware 5.8 or later). Unplug it and hold it to the phone to use NFC instead."
            : "This security key does not offer FIDO2 over this connection.")
      }
      report(.processing)
      // Once the key has done the work, a late cancel no longer undoes it.
      let result = try await body(session, link, serial)
      await link.closeSucceeded(Self.doneMessage)
      return result
    } catch {
      let failure = cancelRequested ? SecurityKeyError.cancelled : Self.map(error, builtInUV: builtInUV)
      await link.closeFailed(failure)
      throw failure
    }
  }

  private func checkCancelled() throws {
    if cancelRequested { throw SecurityKeyError.cancelled }
  }

  /// Passes progress to the current request's handler (repeats are dropped
  /// on the receiving side).
  private func report(_ status: SecurityKeyStatus) {
    onStatus?(status, statusTransport)
  }

  /// What a wait on the key asks of the user: a fingerprint in built-in UV
  /// mode (on a YubiKey Bio every touch lands on the sensor), else a touch.
  private var userWaitStatus: SecurityKeyStatus {
    usesBuiltInUV ? .fingerprintNeeded : .touchNeeded
  }

  private func connect(prompt: String) async throws -> KeyLink {
    connectGeneration &+= 1
    let generation = connectGeneration

    let link: KeyLink
    do {
      link = try await withCheckedThrowingContinuation { continuation in
        connectWaiter = continuation
        connectTask = Task.detached { [weak self] in
          let result: Result<KeyLink, Error>
          do {
            result = .success(try await KeyLink.waitForKey(prompt: prompt))
          } catch {
            result = .failure(error)
          }
          if let self {
            await self.connectFinished(generation: generation, result: result)
          } else if case .success(let link) = result {
            await link.closeQuietly()
          }
        }
        connectTimer = Task.detached { [weak self] in
          do {
            try await Task.sleep(for: Self.connectTimeout)
          } catch {
            return
          }
          await self?.connectDeadlinePassed(generation: generation)
        }
      }
    } catch {
      if let error = error as? SecurityKeyError { throw error }
      if cancelRequested { throw SecurityKeyError.cancelled }
      throw Self.map(error)
    }

    if cancelRequested {
      await link.closeFailed(.cancelled)
      throw SecurityKeyError.cancelled
    }
    return link
  }

  private func connectFinished(generation: Int, result: Result<KeyLink, Error>) async {
    guard generation == connectGeneration, let waiter = connectWaiter else {
      // Nobody waits for this key any more (cancelled or timed out).
      if case .success(let link) = result { await link.closeQuietly() }
      return
    }
    connectWaiter = nil
    connectTask = nil
    connectTimer?.cancel()
    connectTimer = nil
    waiter.resume(with: result)
  }

  private func connectDeadlinePassed(generation: Int) {
    guard generation == connectGeneration else { return }
    abandonConnect(with: .timeout)
  }

  /// Stops waiting for a key. A key that still shows up is closed on arrival.
  private func abandonConnect(with error: SecurityKeyError) {
    guard let waiter = connectWaiter else { return }
    connectWaiter = nil
    connectTask?.cancel()  // dismisses the NFC sheet and stops wired polling
    connectTask = nil
    connectTimer?.cancel()
    connectTimer = nil
    waiter.resume(throwing: error)
  }

  /// Runs a CTAP status stream to its result, keeping the cancel handle while
  /// the key waits for a touch and reporting the waits. Never cancels the
  /// Swift task (YubiKit's streams treat that as a programming error).
  private func finish<R: Sendable>(_ stream: CTAP2.StatusStream<R>) async throws -> R {
    defer { ctapCancel = nil }
    var waited = false
    for try await status in stream {
      switch status {
      case .processing:
        report(.processing)
      case .waitingForUser(let cancel):
        ctapCancel = cancel
        waited = true
        report(userWaitStatus)
        if cancelRequested { await cancel() }
      case .finished(let response):
        if waited { report(.processing) }
        return response
      }
    }
    throw SecurityKeyError.cancelled
  }

  // MARK: Serial number

  /// The YubiKey serial number from the Management application
  /// (DeviceInfo.serialNumber), or nil when the key hides it (YubiKit reports
  /// 0), is not a YubiKey, or the read fails for any reason; it never fails
  /// the request. It must run before the CTAP2 session is made: making that
  /// session selects the FIDO applet again, so a failed or partial
  /// Management exchange cannot leave CTAP2 talking to the wrong applet.
  /// Never logged.
  private static func readSerial(_ connection: any SmartCardConnection) async -> Int? {
    guard let management = try? await Management.Session.makeSession(connection: connection),
      let info = try? await management.getDeviceInfo(),
      info.serialNumber != 0
    else { return nil }
    return Int(exactly: info.serialNumber)
  }

  // MARK: CTAP steps

  /// CTAP 2.1 authenticatorSelection: the key blinks until it is touched.
  /// Keys that only report FIDO_2_0/FIDO_2_1_PRE (YubiKey 5 firmware 5.2 to
  /// 5.4) are skipped without asking, as browsers and python-fido2 do; a key
  /// that answers "invalid command" anyway is skipped too. Returns whether
  /// the touch happened.
  private func touchToSelect(
    _ session: CTAP2.Session,
    info: CTAP2.GetInfo.Response
  ) async throws -> Bool {
    guard info.versions.contains(.fido2_1) else { return false }
    report(.touchNeeded)
    do {
      try await finish(await session.selection())
    } catch let error as CTAP2.SessionError where !cancelRequested && Self.isUnknownCommand(error) {
      report(.processing)
      return false
    }
    report(.processing)
    return true
  }

  /// A PIN or built-in UV token with `permissions`, bound to `rpId`.
  private func authToken(
    _ session: CTAP2.Session,
    _ verification: SecurityKeyVerification,
    permissions: CTAP2.ClientPin.Permission,
    rpId: String,
    protocol pinProtocol: CTAP2.ClientPin.ProtocolVersion
  ) async throws -> CTAP2.Token {
    switch verification {
    case .pin(let pin):
      return try await pinToken(
        session, pin: pin, permissions: permissions, rpId: rpId, protocol: pinProtocol)
    case .uv:
      return try await uvToken(
        session, permissions: permissions, rpId: rpId, protocol: pinProtocol)
    }
  }

  /// getPinUvAuthTokenUsingUvWithPermissions: the key waits for a matching
  /// fingerprint. YubiKit 1.4.0 only exposes this call without keepalive
  /// updates (getPinUVTokenUpdates is internal), so the wait is reported
  /// around it, and cancel() cannot abort it on the key: a cancelled request
  /// ends once the key stops waiting.
  private func uvToken(
    _ session: CTAP2.Session,
    permissions: CTAP2.ClientPin.Permission,
    rpId: String,
    protocol pinProtocol: CTAP2.ClientPin.ProtocolVersion
  ) async throws -> CTAP2.Token {
    report(.fingerprintNeeded)
    do {
      let token = try await session.getPinUVToken(
        using: .uv, permissions: permissions, rpId: rpId, protocol: pinProtocol)
      report(.processing)
      return token
    } catch CTAP2.SessionError.ctapError(.uvInvalid, _) {
      let retries = try? await session.getUVRetries(protocol: pinProtocol)
      throw SecurityKeyError(.uvInvalid, "Fingerprint not recognized.", retries: retries)
    } catch CTAP2.SessionError.ctapError(.uvBlocked, _),
      CTAP2.SessionError.ctapError(.puatRequired, _)
    {
      throw SecurityKeyError.uvBlocked
    } catch CTAP2.SessionError.featureNotSupported,
      CTAP2.SessionError.ctapError(.notAllowed, _),
      CTAP2.SessionError.ctapError(.invalidSubcommand, _)
    {
      // YubiKit's own check (no pinUvAuthToken), or the key turning down
      // built-in UV that it has not got or has not set up.
      throw SecurityKeyError(
        .uvNotConfigured, "This security key cannot use a fingerprint for this.")
    }
  }

  private func pinToken(
    _ session: CTAP2.Session,
    pin: String,
    permissions: CTAP2.ClientPin.Permission,
    rpId: String,
    protocol pinProtocol: CTAP2.ClientPin.ProtocolVersion
  ) async throws -> CTAP2.Token {
    // getPinUVToken uses getPinUvAuthTokenUsingPinWithPermissions when the key
    // reports options.pinUvAuthToken, otherwise the legacy getPinToken.
    do {
      return try await session.getPinUVToken(
        using: .pin(pin), permissions: permissions, rpId: rpId, protocol: pinProtocol)
    } catch CTAP2.SessionError.ctapError(.pinInvalid, _) {
      let retries = try? await session.getPinRetries(protocol: pinProtocol).retries
      throw SecurityKeyError(.pinInvalid, "Wrong PIN.", retries: retries)
    }
  }

  /// getAssertion with the hmac-secret extension and one 32-byte salt.
  ///
  /// HmacSecret(session:) does the CTAP 2.1 §12.5 work: getKeyAgreement,
  /// encapsulate with the session's PIN protocol, saltEnc = encrypt(salt),
  /// saltAuth = authenticate(saltEnc); output() decrypts the result.
  private func assertHmacSecret(
    _ session: CTAP2.Session,
    rpId: String,
    salt: Data,
    allowList: [Data],
    token: CTAP2.Token,
    serial: Int?
  ) async throws -> SecurityKeySecret {
    let hmacSecret = try await CTAP2.Extension.HmacSecret(session: session)
    let parameters = CTAP2.GetAssertion.Parameters(
      rpId: rpId,
      clientDataHash: Self.clientDataHash,
      allowList: allowList.map { WebAuthn.CredentialDescriptor(id: $0) },
      extensions: [try hmacSecret.getAssertion.input(salt1: salt)]
    )
    let response = try await finish(
      await session.getAssertion(parameters: parameters, token: token))

    let secrets: CTAP2.Extension.HmacSecret.Secrets?
    do {
      secrets = try hmacSecret.getAssertion.output(from: response)
    } catch {
      throw SecurityKeyError.unsupported("The security key returned an unreadable hmac-secret.")
    }
    guard let secrets, secrets.second == nil, secrets.first.count == Self.saltLength else {
      throw SecurityKeyError.unsupported("The security key did not return a 32-byte hmac-secret.")
    }

    let credentialId: Data
    if let id = response.credential?.id {
      guard allowList.contains(id) else {
        throw SecurityKeyError.unknown("The security key answered for an unexpected credential.")
      }
      credentialId = id
    } else if allowList.count == 1 {
      credentialId = allowList[0]
    } else {
      throw SecurityKeyError.unknown("The security key did not say which credential it used.")
    }
    return SecurityKeySecret(credentialId: credentialId, serial: serial, hmacSecret: secrets.first)
  }

  // MARK: Helpers

  private static func validate(
    rpId: String,
    salt: Data,
    verification: SecurityKeyVerification
  ) throws {
    guard !rpId.isEmpty else { throw SecurityKeyError.unknown("Invalid argument: rpId is empty.") }
    guard salt.count == saltLength else {
      throw SecurityKeyError.unknown("Invalid argument: salt must be 32 bytes.")
    }
    if case .pin(let pin) = verification, pin.isEmpty {
      throw SecurityKeyError(.pinInvalid, "The PIN is empty.")
    }
  }

  /// Checks, before any token is asked for, that the key can verify the user
  /// the way `verification` says.
  private static func requireUsable(
    _ info: CTAP2.GetInfo.Response,
    for verification: SecurityKeyVerification
  ) throws {
    switch verification {
    case .pin:
      guard info.options.clientPin == true else { throw SecurityKeyError.pinNotSet }
      if info.forcePinChange == true { throw SecurityKeyError.pinChangeRequired }
      if info.options.noMcGaPermissionsWithClientPin == true {
        throw SecurityKeyError.unsupported("This security key does not accept a PIN for this.")
      }
    case .uv:
      switch info.options.userVerification {
      case .none:
        throw SecurityKeyError(.uvNotConfigured, "This security key has no fingerprint reader.")
      case .some(false):
        throw SecurityKeyError(
          .uvNotConfigured, "This security key has no fingerprint set up yet.")
      case .some(true):
        break
      }
      guard info.options.pinUVAuthToken == true else {
        throw SecurityKeyError(
          .uvNotConfigured, "This security key cannot use a fingerprint for this.")
      }
    }
  }

  /// The key does not know the command: CTAP1_ERR_INVALID_COMMAND, YubiKit's
  /// own feature check, or ISO 7816 "instruction not supported" from the
  /// smart card layer.
  private static func isUnknownCommand(_ error: CTAP2.SessionError) -> Bool {
    switch error {
    case .ctapError(.invalidCommand, _), .featureNotSupported:
      return true
    case .failedResponse(let response, _):
      return response.status == .invalidInstruction
    default:
      return false
    }
  }

  private static func pinProtocol(for info: CTAP2.GetInfo.Response)
    -> CTAP2.ClientPin.ProtocolVersion
  {
    info.pinUVAuthProtocols.contains(.v2) ? .v2 : .v1
  }

  private static func versionString(_ version: CTAP2.GetInfo.AuthenticatorVersion) -> String {
    switch version {
    case .u2fV2: return "U2F_V2"
    case .fido2_0: return "FIDO_2_0"
    case .fido2_1Pre: return "FIDO_2_1_PRE"
    case .fido2_1: return "FIDO_2_1"
    case .unknown(let value): return value
    }
  }

  // MARK: Error mapping

  /// `builtInUV`: the request verifies with built-in UV, so PUAT_REQUIRED
  /// means that UV is no longer usable.
  static func map(_ error: Error, builtInUV: Bool = false) -> SecurityKeyError {
    switch error {
    case let error as SecurityKeyError:
      return error
    case let error as CTAP2.SessionError:
      return map(session: error, builtInUV: builtInUV)
    case let error as SmartCardConnectionError:
      return map(connection: error)
    case is CancellationError:
      return .cancelled
    default:
      return .unknown(error.localizedDescription)
    }
  }

  private static func map(session error: CTAP2.SessionError, builtInUV: Bool) -> SecurityKeyError {
    switch error {
    case .ctapError(let ctap, _):
      return map(ctap: ctap, builtInUV: builtInUV)
    case .connectionError(let connection, _):
      return map(connection: connection)
    case .extensionNotSupported(let identifier, _):
      return .unsupported("This security key does not support \(identifier.value).")
    case .featureNotSupported:
      return .unsupported("This security key does not support this.")
    case .timeout:
      return .timeout
    case .failedResponse(let response, _):
      return SecurityKeyError(
        .transport,
        "The security key returned status \(String(format: "%04X", response.rawStatus)).")
    case .hidError, .fidoConnectionError, .initializationFailed:
      return SecurityKeyError(.transport, "Lost the connection to the security key.")
    case .responseParseError(let message, _), .illegalArgument(let message, _),
      .dataProcessingError(let message, _), .cryptoError(let message, _, _):
      return .unknown(message)
    default:
      return .unknown("The security key request failed.")
    }
  }

  private static func map(ctap error: CTAP2.Error, builtInUV: Bool) -> SecurityKeyError {
    switch error {
    case .pinInvalid:
      return SecurityKeyError(.pinInvalid, "Wrong PIN.")
    case .pinBlocked:
      return SecurityKeyError(.pinBlocked, "This security key's PIN is blocked.")
    case .pinAuthBlocked:
      return SecurityKeyError(
        .pinAuthBlocked, "Too many wrong PINs. Remove or lift the key, then try again.")
    case .pinPolicyViolation:
      return SecurityKeyError(.pinPolicy, "The PIN does not meet this security key's rules.")
    case .pinNotSet:
      return .pinNotSet
    case .uvInvalid:
      return SecurityKeyError(.uvInvalid, "Fingerprint not recognized.")
    case .uvBlocked:
      return .uvBlocked
    case .puatRequired where builtInUV:
      return .uvBlocked
    case .noCredentials:
      return .noCredentials
    case .credentialExcluded:
      return SecurityKeyError(
        .credentialExcluded, "This security key is already set up for this wallet.")
    case .keepaliveCancel:
      return .cancelled
    case .userActionTimeout, .actionTimeout:
      return SecurityKeyError(.timeout, "The security key was not touched in time.")
    case .unsupportedExtension, .unsupportedAlgorithm, .unsupportedOption:
      return .unsupported("This security key does not support this request.")
    default:
      return .unknown("The security key reported an error (\(error)).")
    }
  }

  private static func map(connection error: SmartCardConnectionError) -> SecurityKeyError {
    switch error {
    case .cancelled, .cancelledByUser:
      return .cancelled
    case .busy:
      return SecurityKeyError(.busy, "The security key is busy with another request.")
    case .unsupported:
      return .unsupported("This device cannot reach a security key this way.")
    case .setupFailed(_, let underlying?), .transmitFailed(_, let underlying?):
      if let nfcError = underlying as? NFCReaderError { return map(nfc: nfcError) }
      return SecurityKeyError(.transport, "Lost the connection to the security key.")
    default:
      return SecurityKeyError(
        .transport, "Lost the connection to the security key. Hold it still and try again.")
    }
  }

  private static func map(nfc error: NFCReaderError) -> SecurityKeyError {
    switch error.code {
    case .readerSessionInvalidationErrorUserCanceled, .readerTransceiveErrorSessionInvalidated:
      return .cancelled
    case .readerSessionInvalidationErrorSessionTimeout:
      return .timeout
    case .readerErrorUnsupportedFeature:
      return .unsupported("NFC is not available on this device.")
    case .readerErrorSecurityViolation:
      return .unsupported("This app is not allowed to use NFC.")
    default:
      return SecurityKeyError(
        .transport, "Lost the connection to the security key. Hold it still and try again.")
    }
  }
}

// MARK: - Connections

/// An open connection to a key and how it is attached.
private struct KeyLink: Sendable {
  let connection: any SmartCardConnection
  let transport: SecurityKeyTransport

  /// Updates the NFC sheet; wired keys have no system UI.
  func setStatus(_ message: String) async {
    if let nfc = connection.nfcConnection {
      await nfc.setAlertMessage(message)
    }
  }

  func closeSucceeded(_ message: String) async {
    if let nfc = connection.nfcConnection {
      await nfc.close(message: message)
    } else {
      await connection.close(error: nil)
    }
  }

  func closeFailed(_ error: SecurityKeyError) async {
    // On NFC the sheet shows error.localizedDescription.
    await connection.close(error: error)
  }

  func closeQuietly() async {
    if let nfc = connection.nfcConnection {
      await nfc.close(message: nil)
    } else {
      await connection.close(error: nil)
    }
  }

  /// A wired key that is already attached wins; otherwise the NFC sheet shows
  /// `prompt` while wired keys are still watched for. Without NFC, waits for a
  /// wired key. Cancelling the calling task dismisses the sheet.
  static func waitForKey(prompt: String) async throws -> KeyLink {
    if let wired = await attachWired() { return wired }
    guard NFCTagReaderSession.readingAvailable else { return try await pollWired() }

    return try await withThrowingTaskGroup(of: KeyLink.self, returning: KeyLink.self) { group in
      group.addTask {
        let nfc = try await NFCSmartCardConnection(alertMessage: prompt)
        return KeyLink(connection: nfc, transport: .nfc)
      }
      group.addTask {
        try await pollWired()
      }

      var winner: KeyLink?
      var failure: Error?
      do {
        winner = try await group.next()
      } catch {
        failure = error
      }
      group.cancelAll()
      // Both could connect at once; keep the first and release the other.
      while !group.isEmpty {
        do {
          if let late = try await group.next() {
            if winner == nil && failure == nil {
              winner = late
            } else {
              await late.closeQuietly()
            }
          }
        } catch {}
      }
      if let winner { return winner }
      throw failure ?? CancellationError()
    }
  }

  private static func pollWired() async throws -> KeyLink {
    while true {
      try Task.checkCancellation()
      if let link = await attachWired() { return link }
      try await Task.sleep(for: .milliseconds(500))
    }
  }

  /// Connects to a key that is plugged in right now, or returns nil. A failed
  /// attempt (say, a key pulled out mid-connect) counts as no key yet.
  private static func attachWired() async -> KeyLink? {
    // Only connect over Lightning once a 5Ci is attached: YubiKit's
    // Lightning connect otherwise waits indefinitely and ignores cancellation.
    if await lightningKeyAttached(),
      let connection = try? await LightningSmartCardConnection()
    {
      return KeyLink(connection: connection, transport: .lightning)
    }
    // Without a slot manager (no smart card entitlement, or the simulator)
    // YubiKit asserts in debug builds, so check first.
    guard TKSmartCardSlotManager.default != nil,
      let slot = try? await USBSmartCardConnection.availableDevices().first,
      let connection = try? await USBSmartCardConnection(slot: slot)
    else { return nil }
    return KeyLink(connection: connection, transport: .usb)
  }

  @MainActor
  private static func lightningKeyAttached() -> Bool {
    EAAccessoryManager.shared().connectedAccessories.contains {
      $0.manufacturer == "Yubico" && $0.protocolStrings.contains("com.yubico.ylp")
    }
  }
}

// MARK: - Device and buffer helpers

private enum DeviceModel {
  /// iPhones before the iPhone 15 family have a Lightning port (iPhone15,2
  /// and iPhone15,3 are the iPhone 14 Pro models). iPads fall back to the
  /// smart card check in capabilities().
  static var hasLightningPort: Bool {
    var system = utsname()
    uname(&system)
    let identifier = withUnsafeBytes(of: &system.machine) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    guard identifier.hasPrefix("iPhone") else { return false }
    let numbers = identifier.dropFirst("iPhone".count).split(separator: ",").compactMap { Int($0) }
    guard numbers.count == 2 else { return false }
    return numbers[0] < 15 || (numbers[0] == 15 && numbers[1] <= 3)
  }
}

extension Data {
  /// Overwrites this buffer with zeros (best effort: copies made elsewhere,
  /// including inside YubiKit, are not reached).
  mutating func wipe() {
    guard !isEmpty else { return }
    resetBytes(in: startIndex..<endIndex)
  }
}
