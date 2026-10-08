@preconcurrency import Flutter
import Foundation

/// Method channel for FIDO2 security keys (FHSE wallet-file encryption).
///
/// Thin glue over SecurityKeyOperations: it reads arguments, allows one key
/// request at a time (`busy` otherwise), runs the work off the main thread and
/// replies on the main thread. While a request runs, its progress goes to Dart
/// as `status` calls on this channel. All state here is touched on the main
/// thread only, which is where Flutter delivers method calls.
final class SecurityKeyChannel: @unchecked Sendable {
  static let name = "org.magicgrants.skylight/security_key"

  private static let defaultPrompt = "Hold your security key near the top of your iPhone."

  private let channel: FlutterMethodChannel
  private let operations = SecurityKeyOperations()
  private var isBusy = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    dispatchPrecondition(condition: .onQueue(.main))
    let args = call.arguments as? [String: Any] ?? [:]
    let prompt = (args["prompt"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultPrompt

    switch call.method {
    case "capabilities":
      let capabilities = SecurityKeyOperations.capabilities()
      result(["nfc": capabilities.nfc, "usb": capabilities.usb])

    case "cancel":
      let operations = self.operations
      Task.detached { await operations.cancel() }
      result(nil)

    case "inspect":
      // Absent or null means no touch.
      let touch = args["touch"] as? Bool ?? false
      run(result) { operations, onStatus in
        let info = try await operations.inspect(prompt: prompt, touch: touch, onStatus: onStatus)
        return .info(info)
      }

    case "setPin":
      guard let newPin = args["newPin"] as? String else {
        return result(Self.badArgument("newPin"))
      }
      let expectSerial: Int?
      do {
        expectSerial = try Self.expectSerial(args)
      } catch {
        return result(Self.badArgument(error.name))
      }
      run(result) { operations, onStatus in
        try await operations.setPin(
          newPin: newPin, expectSerial: expectSerial, prompt: prompt, onStatus: onStatus)
        return .none
      }

    case "enroll":
      guard let rpId = args["rpId"] as? String else { return result(Self.badArgument("rpId")) }
      guard let userId = Self.bytes(args["userId"]) else { return result(Self.badArgument("userId")) }
      guard let salt = Self.bytes(args["salt"]) else { return result(Self.badArgument("salt")) }
      let verification: SecurityKeyVerification
      let expectSerial: Int?
      do {
        verification = try Self.verification(args)
        expectSerial = try Self.expectSerial(args)
      } catch {
        return result(Self.badArgument(error.name))
      }
      // Absent or null means nothing to exclude.
      let excludedArgument = args["excludeCredentialIds"].flatMap { $0 is NSNull ? nil : $0 }
      guard let excluded = Self.byteList(excludedArgument ?? [Any]()) else {
        return result(Self.badArgument("excludeCredentialIds"))
      }
      run(result) { operations, onStatus in
        let secret = try await operations.enroll(
          rpId: rpId, userId: userId, salt: salt, verification: verification,
          excludeCredentialIds: excluded, expectSerial: expectSerial, prompt: prompt,
          onStatus: onStatus)
        return .secret(secret)
      }

    case "getHmacSecret":
      guard let rpId = args["rpId"] as? String else { return result(Self.badArgument("rpId")) }
      guard let salt = Self.bytes(args["salt"]) else { return result(Self.badArgument("salt")) }
      let verification: SecurityKeyVerification
      let expectSerial: Int?
      do {
        verification = try Self.verification(args)
        expectSerial = try Self.expectSerial(args)
      } catch {
        return result(Self.badArgument(error.name))
      }
      guard let credentialIds = Self.byteList(args["credentialIds"]) else {
        return result(Self.badArgument("credentialIds"))
      }
      run(result) { operations, onStatus in
        let secret = try await operations.getHmacSecret(
          rpId: rpId, salt: salt, verification: verification, credentialIds: credentialIds,
          expectSerial: expectSerial, prompt: prompt, onStatus: onStatus)
        return .secret(secret)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Running requests

  /// What a request hands back to the main thread. Only Sendable Swift values
  /// cross threads; Flutter objects are built on the main thread.
  private enum Outcome: Sendable {
    case none
    case info(SecurityKeyInfo)
    case secret(SecurityKeySecret)
  }

  /// FlutterResult is a plain block; it is only ever called on the main thread.
  private struct Reply: @unchecked Sendable {
    let send: FlutterResult
  }

  private func run(
    _ result: @escaping FlutterResult,
    _ work: @escaping @Sendable (SecurityKeyOperations, @escaping SecurityKeyStatusHandler)
      async throws -> Outcome
  ) {
    guard !isBusy else {
      result(Self.flutterError(.busy))
      return
    }
    isBusy = true
    let reply = Reply(send: result)
    let relay = StatusRelay(channel: channel)
    let operations = self.operations
    Task.detached(priority: .userInitiated) { [weak self] in
      let outcome: Result<Outcome, SecurityKeyError>
      do {
        outcome = .success(try await work(operations, { relay.send($0, $1) }))
      } catch {
        outcome = .failure(SecurityKeyOperations.map(error))
      }
      DispatchQueue.main.async {
        self?.isBusy = false
        // Status calls queued before this block have gone out already (the
        // main queue is FIFO); any that come later are dropped.
        relay.close()
        reply.send(Self.encode(outcome))
        // Flutter has its own copy now; zero ours.
        if case .success(.secret(let secret)) = outcome { secret.wipe() }
      }
    }
  }

  /// Sends one request's progress to Dart as `status` calls: on the main
  /// thread, fire and forget, without repeating the last state, and never
  /// once that request's result has gone out.
  private final class StatusRelay: @unchecked Sendable {
    // Main thread only.
    private weak var channel: FlutterMethodChannel?
    private var isOpen = true
    private var last: (state: SecurityKeyStatus, transport: SecurityKeyTransport?)?

    init(channel: FlutterMethodChannel) {
      self.channel = channel
    }

    /// Any thread.
    func send(_ state: SecurityKeyStatus, _ transport: SecurityKeyTransport?) {
      DispatchQueue.main.async { self.deliver(state, transport) }
    }

    /// Main thread, just before the result is sent.
    func close() {
      dispatchPrecondition(condition: .onQueue(.main))
      isOpen = false
    }

    private func deliver(_ state: SecurityKeyStatus, _ transport: SecurityKeyTransport?) {
      guard isOpen, let channel else { return }
      if let last, last.state == state, last.transport == transport { return }
      last = (state, transport)
      channel.invokeMethod(
        "status",
        arguments: [
          "state": state.rawValue,
          "transport": transport?.rawValue ?? NSNull(),
        ] as [String: Any])
    }
  }

  // MARK: Encoding

  private static func encode(_ outcome: Result<Outcome, SecurityKeyError>) -> Any? {
    switch outcome {
    case .failure(let error):
      return flutterError(error)
    case .success(.none):
      return nil
    case .success(.info(let info)):
      return [
        "pinSet": info.pinSet,
        "pinRetries": info.pinRetries.map { NSNumber(value: $0) } ?? NSNull(),
        "hmacSecret": info.hmacSecret,
        "credProtect": info.credProtect,
        "aaguid": info.aaguid.map { FlutterStandardTypedData(bytes: $0) } ?? NSNull(),
        "versions": info.versions,
        "transport": info.transport.rawValue,
        "serial": info.serial.map { NSNumber(value: $0) } ?? NSNull(),
        "uv": info.uv,
        "uvSupported": info.uvSupported,
        "uvRetries": info.uvRetries.map { NSNumber(value: $0) } ?? NSNull(),
        "pinUvAuthToken": info.pinUvAuthToken,
        "minPinLength": info.minPinLength,
        "forcePinChange": info.forcePinChange,
        "touched": info.touched,
      ] as [String: Any]
    case .success(.secret(let secret)):
      // An independent NSData, so wiping `secret` afterwards cannot reach
      // (or be blocked by) the buffer handed to Flutter.
      let output = secret.withHmacSecret { data in
        data.withUnsafeBytes { NSData(bytes: $0.baseAddress, length: $0.count) }
      }
      return [
        "credentialId": FlutterStandardTypedData(bytes: secret.credentialId),
        "hmacSecret": FlutterStandardTypedData(bytes: output as Data),
        "serial": secret.serial.map { NSNumber(value: $0) } ?? NSNull(),
      ] as [String: Any]
    }
  }

  private static func flutterError(_ error: SecurityKeyError) -> FlutterError {
    FlutterError(
      code: error.code.rawValue,
      message: error.message,
      details: error.retries.map { NSNumber(value: $0) }
    )
  }

  private static func badArgument(_ name: String) -> FlutterError {
    FlutterError(code: SecurityKeyError.Code.unknown.rawValue, message: "Invalid argument: \(name)", details: nil)
  }

  /// The argument that was missing or malformed.
  private struct BadArgument: Error {
    let name: String
  }

  /// Reads `verification` ("pin" when absent or null, for safety) and, for
  /// "pin", the PIN. In "uv" mode any `pin` is ignored.
  private static func verification(
    _ args: [String: Any]
  ) throws(BadArgument) -> SecurityKeyVerification {
    switch args["verification"] {
    case nil, is NSNull, "pin" as String:
      guard let pin = args["pin"] as? String else { throw BadArgument(name: "pin") }
      return .pin(pin)
    case "uv" as String:
      return .uv
    default:
      throw BadArgument(name: "verification")
    }
  }

  /// Reads `expectSerial`: nil when absent or null, else an integer.
  private static func expectSerial(_ args: [String: Any]) throws(BadArgument) -> Int? {
    switch args["expectSerial"] {
    case nil, is NSNull:
      return nil
    case let serial as Int:
      return serial
    default:
      throw BadArgument(name: "expectSerial")
    }
  }

  private static func bytes(_ value: Any?) -> Data? {
    (value as? FlutterStandardTypedData)?.data
  }

  private static func byteList(_ value: Any?) -> [Data]? {
    guard let list = value as? [Any] else { return nil }
    var result: [Data] = []
    result.reserveCapacity(list.count)
    for item in list {
      guard let data = bytes(item) else { return nil }
      result.append(data)
    }
    return result
  }
}
