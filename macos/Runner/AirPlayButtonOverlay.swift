// macos/Runner/AirPlayButtonOverlay.swift
import AVKit
import AppKit

/// Hosts an `AVRoutePickerView` as a floating overlay directly on the
/// window's content view (a sibling of the `FlutterViewController`'s own
/// view), rather than as a registered Flutter platform view -- see this
/// file's own doc comment context in the implementation plan for why.
/// Positioned/shown/hidden to track the Flutter-side `AirPlayButton`
/// placeholder's on-screen frame, reported via
/// `setButtonFrame`/`setButtonVisible` method-channel calls (see
/// `AirPlayCastEngine`'s sibling wiring in `MainFlutterWindow.swift`).
class AirPlayButtonOverlay {
  private let routePickerView: AVRoutePickerView

  init(contentView: NSView) {
    routePickerView = AVRoutePickerView(frame: .zero)
    routePickerView.isHidden = true
    contentView.addSubview(routePickerView)
  }

  /// `x`/`y` are expected in **top-left-origin** coordinates, matching
  /// Flutter's own coordinate space (e.g. what `RenderBox.localToGlobal()`
  /// produces on the Dart side -- see `AirPlayButton`'s frame reporting).
  /// AppKit views default to a **bottom-left-origin** coordinate system
  /// (`isFlipped == false`), so this converts `y` accordingly unless the
  /// superview itself is flipped (already top-left-origin), to avoid the
  /// overlay landing vertically mirrored relative to the Flutter-side
  /// placeholder it's meant to track.
  func setFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    guard let superview = routePickerView.superview else {
      routePickerView.frame = NSRect(x: x, y: y, width: width, height: height)
      return
    }
    let adjustedY = superview.isFlipped ? y : superview.bounds.height - y - height
    routePickerView.frame = NSRect(x: x, y: adjustedY, width: width, height: height)
  }

  func setVisible(_ visible: Bool) {
    routePickerView.isHidden = !visible
  }
}
