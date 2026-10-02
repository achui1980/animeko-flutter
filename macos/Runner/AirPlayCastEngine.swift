// macos/Runner/AirPlayCastEngine.swift
import AVFoundation
import CoreAudio
import FlutterMacOS

/// Wraps a dedicated, cast-only `AVPlayer` and bridges its lifecycle to
/// Flutter over a `MethodChannel` (commands) and `EventChannel`
/// (lifecycle events). This is a second playback engine, entirely
/// separate from the app's primary media_kit/libmpv player — libmpv has
/// no AirPlay support and mpv's own maintainers have explicitly rejected
/// adding it (see
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §2),
/// so AirPlay casting requires this standalone `AVPlayer`-based path.
class AirPlayCastEngine: NSObject, FlutterStreamHandler {
  private let player = AVPlayer()
  // Retained to keep the channel (and its registered `setMethodCallHandler`
  // closure, owned by `MainFlutterWindow.swift`/Task 6) alive for as long as
  // this engine is alive; never called directly after `init`.
  private let methodChannel: FlutterMethodChannel
  private var eventSink: FlutterEventSink?
  private var statusObservation: NSKeyValueObservation?
  private var externalPlaybackObservation: NSKeyValueObservation?

  init(methodChannel: FlutterMethodChannel) {
    self.methodChannel = methodChannel
    super.init()
    // AVFoundation does not guarantee which thread KVO notifications are
    // delivered on, but `FlutterEventSink` must only be invoked on the
    // main/platform thread — hop to main before touching it.
    externalPlaybackObservation = player.observe(\.isExternalPlaybackActive, options: [.new]) {
      [weak self] player, change in
      guard let self = self, let isActive = change.newValue else { return }
      if isActive {
        let deviceName = self.resolveActiveOutputDeviceName()
        DispatchQueue.main.async {
          self.eventSink?(["type": "activated", "deviceName": deviceName])
        }
      } else {
        let positionMs = Int(player.currentTime().seconds * 1000)
        DispatchQueue.main.async {
          self.eventSink?(["type": "deactivated", "lastPositionMs": positionMs])
        }
      }
    }
  }

  /// Routes Flutter method-channel calls to the matching `AVPlayer`
  /// operation. Registered as `methodChannel.setMethodCallHandler` by
  /// `MainFlutterWindow.swift` (Task 6).
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startCast":
      guard let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString),
        let positionMs = args["positionMs"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "startCast missing url/positionMs", details: nil))
        return
      }
      let headers = args["headers"] as? [String: String] ?? [:]
      startCast(url: url, headers: headers, positionMs: positionMs)
      result(nil)
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "seek":
      guard let args = call.arguments as? [String: Any],
        let positionMs = args["positionMs"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "seek missing positionMs", details: nil))
        return
      }
      player.seek(to: CMTime(seconds: Double(positionMs) / 1000, preferredTimescale: 1000))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCast(url: URL, headers: [String: String], positionMs: Int) {
    statusObservation?.invalidate()
    let options: [String: Any] = headers.isEmpty
      ? [:]
      // "AVURLAssetHTTPHeaderFieldsKey" is passed as a raw string because the
      // real `AVURLAssetHTTPHeaderFieldsKey` symbol is unavailable in this
      // SDK (resolution failure confirmed via `flutter build macos`); the
      // string value is stable, documented AVFoundation API regardless.
      : ["AVURLAssetHTTPHeaderFieldsKey": headers]
    let asset = AVURLAsset(url: url, options: options)
    let item = AVPlayerItem(asset: asset)
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard item.status == .failed else { return }
      let reason = item.error?.localizedDescription ?? "未知错误"
      DispatchQueue.main.async {
        self?.eventSink?(["type": "failed", "reason": reason])
      }
    }
    player.replaceCurrentItem(with: item)
    player.seek(to: CMTime(seconds: Double(positionMs) / 1000, preferredTimescale: 1000)) { [weak self] _ in
      self?.player.play()
    }
  }

  /// Resolves the active AirPlay receiver's display name via Core
  /// Audio: while `isExternalPlaybackActive` is true, the receiver is
  /// the system's default audio output device, so querying that
  /// device's name reflects the connected receiver. Falls back to a
  /// generic label if either Core Audio call fails.
  private func resolveActiveOutputDeviceName() -> String {
    var deviceId = AudioDeviceID(0)
    var deviceIdSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &deviceIdSize, &deviceId
    )
    guard status == noErr else { return "AirPlay 设备" }

    var name: Unmanaged<CFString>?
    var nameSize = UInt32(MemoryLayout<CFString?>.size)
    var nameAddress = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    status = withUnsafeMutablePointer(to: &name) { ptr in
      AudioObjectGetPropertyData(deviceId, &nameAddress, 0, nil, &nameSize, ptr)
    }
    guard status == noErr, let cfName = name?.takeRetainedValue() else { return "AirPlay 设备" }
    return cfName as String
  }

  // MARK: FlutterStreamHandler (EventChannel)

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
