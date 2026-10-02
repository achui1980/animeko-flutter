// macos/Runner/MainFlutterWindow.swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var airPlayCastEngine: AirPlayCastEngine?
  private var airPlayButtonOverlay: AirPlayButtonOverlay?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    let methodChannel = FlutterMethodChannel(name: "animeko/airplay_cast", binaryMessenger: messenger)
    let eventChannel = FlutterEventChannel(name: "animeko/airplay_cast_events", binaryMessenger: messenger)

    let engine = AirPlayCastEngine(methodChannel: methodChannel)
    let overlay = AirPlayButtonOverlay(contentView: flutterViewController.view)

    // `setButtonFrame`/`setButtonVisible` control the native floating AirPlay
    // overlay (Task 5) and are intercepted here rather than forwarded to
    // `AirPlayCastEngine`, which only knows about playback (`startCast`/
    // `play`/`pause`/`seek`). Malformed args for these two methods return an
    // explicit `bad_args` `FlutterError` rather than falling through to
    // `engine.handle`, which would otherwise report a misleading
    // "method not implemented" for a method that *is* implemented.
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "setButtonFrame":
        guard let args = call.arguments as? [String: Any],
          let x = args["x"] as? Double, let y = args["y"] as? Double,
          let width = args["width"] as? Double, let height = args["height"] as? Double
        else {
          result(FlutterError(code: "bad_args", message: "setButtonFrame requires x, y, width, height", details: nil))
          return
        }
        overlay.setFrame(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        result(nil)
      case "setButtonVisible":
        guard let args = call.arguments as? [String: Any], let visible = args["visible"] as? Bool else {
          result(FlutterError(code: "bad_args", message: "setButtonVisible requires visible", details: nil))
          return
        }
        overlay.setVisible(visible)
        result(nil)
      default:
        engine.handle(call, result: result)
      }
    }
    eventChannel.setStreamHandler(engine)

    self.airPlayCastEngine = engine
    self.airPlayButtonOverlay = overlay

    super.awakeFromNib()
  }
}
