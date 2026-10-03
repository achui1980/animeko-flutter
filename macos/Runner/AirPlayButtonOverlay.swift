// macos/Runner/AirPlayButtonOverlay.swift
import AVKit
import AppKit

/// Hosts an `AVRoutePickerView` inside a separate, transparent, borderless
/// child `NSWindow` layered on top of the main window via
/// `NSWindow.addChildWindow(_:ordered:)`, rather than as a plain `NSView`
/// subview of `flutterViewController.view` (the original approach, which
/// turned out not to work -- see below) or as a registered Flutter
/// platform view (ruled out separately: Flutter's macOS `AppKitView`
/// gesture-passthrough support isn't fully functional as of this
/// project's pinned Flutter 3.41.6, and `AVRoutePickerView` needs a
/// genuine native mouse-down with no programmatic-trigger API).
///
/// **Why not a plain subview of the Flutter view (first attempt):**
/// Flutter's macOS engine composites its own rendered content by having
/// `FlutterSurfaceManager` call `[containingLayer addSublayer:...]`
/// directly on the Flutter view's own `CALayer` on *every rendered
/// frame* (confirmed via the engine source,
/// `FlutterSurfaceManager.mm`'s `commit:` method). A plain `NSView`
/// subview added once at startup becomes a sibling sublayer in that same
/// layer tree, and Flutter's own continuously-appended frame layers can
/// end up stacked on top of it as new frames render, burying it
/// invisibly behind Flutter's content regardless of `isHidden`/frame
/// correctness. (A related confirmed symptom of this same subsystem:
/// flutter/flutter#191154, where macOS Impeller renders content sharing
/// a backing layer with a platform view as solid black.) A separate
/// child `NSWindow` sidesteps this entirely -- window-level compositing
/// by the window server is independent of either window's internal
/// `CALayer` tree, so the overlay is guaranteed to render above the main
/// window's Flutter content no matter how Flutter manages its own
/// layers.
///
/// Positioned/shown/hidden to track the Flutter-side `AirPlayButton`
/// placeholder's on-screen frame, reported via
/// `setButtonFrame`/`setButtonVisible` method-channel calls (see
/// `AirPlayCastEngine`'s sibling wiring in `MainFlutterWindow.swift`).
class AirPlayButtonOverlay {
  private let routePickerView: AVRoutePickerView
  private let overlayWindow: NSWindow
  private weak var flutterView: NSView?

  init(parentWindow: NSWindow, flutterView: NSView) {
    self.flutterView = flutterView
    routePickerView = AVRoutePickerView(frame: NSRect(x: 0, y: 0, width: 44, height: 44))

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 44, height: 44),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isReleasedWhenClosed = false
    window.ignoresMouseEvents = false
    window.contentView = routePickerView

    overlayWindow = window
    parentWindow.addChildWindow(overlayWindow, ordered: .above)
    overlayWindow.orderOut(nil)
  }

  /// `x`/`y` are in the Flutter view's own local coordinate space
  /// (top-left origin, matching what `RenderBox.localToGlobal()`
  /// produces on the Dart side -- see `AirPlayButton`'s frame
  /// reporting). Converted to screen coordinates via the Flutter view's
  /// own `convert(_:to:)` and the parent window's `convertToScreen(_:)`
  /// rather than a manual Y-flip -- this defers entirely to AppKit's own
  /// coordinate semantics (which already account for whether the
  /// Flutter view is flipped) instead of guessing at them.
  func setFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    guard let flutterView, let parentWindow = flutterView.window else { return }
    let localRect = NSRect(x: x, y: y, width: width, height: height)
    let windowRect = flutterView.convert(localRect, to: nil)
    let screenRect = parentWindow.convertToScreen(windowRect)
    overlayWindow.setFrame(screenRect, display: true)
    routePickerView.frame = NSRect(origin: .zero, size: screenRect.size)
  }

  func setVisible(_ visible: Bool) {
    if visible {
      overlayWindow.orderFront(nil)
    } else {
      overlayWindow.orderOut(nil)
    }
  }
}
