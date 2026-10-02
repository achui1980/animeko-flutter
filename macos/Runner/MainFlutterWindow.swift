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

    methodChannel.setMethodCallHandler { call, result in
      if call.method == "setButtonFrame", let args = call.arguments as? [String: Any],
        let x = args["x"] as? Double, let y = args["y"] as? Double,
        let width = args["width"] as? Double, let height = args["height"] as? Double
      {
        overlay.setFrame(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        result(nil)
        return
      }
      if call.method == "setButtonVisible", let args = call.arguments as? [String: Any],
        let visible = args["visible"] as? Bool
      {
        overlay.setVisible(visible)
        result(nil)
        return
      }
      engine.handle(call, result: result)
    }
    eventChannel.setStreamHandler(engine)

    self.airPlayCastEngine = engine
    self.airPlayButtonOverlay = overlay

    super.awakeFromNib()
  }
}
