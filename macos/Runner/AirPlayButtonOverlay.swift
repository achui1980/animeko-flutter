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
  private let labelView: NSTextField
  private let containerView: NSView
  private let overlayWindow: NSWindow
  private weak var flutterView: NSView?

  init(parentWindow: NSWindow, flutterView: NSView) {
    self.flutterView = flutterView

    let initialFrame = NSRect(x: 0, y: 0, width: 44, height: 44)

    // `AVRoutePickerView`'s own built-in icon can't be restyled (Apple
    // doesn't expose an API to swap its glyph), and its default rendering
    // at this icon's small size looked garbled/unclear in testing. So the
    // *visible* control here is a plain "TV" text label we draw ourselves
    // (matching the other player-bar icons' white-on-transparent look),
    // while the real `AVRoutePickerView` is layered on top at a near-zero
    // (but nonzero) alpha so it still receives the real mouse-down needed
    // to open the system AirPlay device picker -- `NSView.alphaValue`
    // only affects rendering, not hit-testing, so clicks still land on it.
    labelView = NSTextField(labelWithString: "TV")
    labelView.frame = initialFrame
    labelView.alignment = .center
    labelView.font = NSFont.boldSystemFont(ofSize: 15)
    labelView.textColor = .white
    labelView.backgroundColor = .clear
    labelView.isBezeled = false
    labelView.isEditable = false
    labelView.isSelectable = false
    // NSTextField's content is vertically top-aligned by default; nudge
    // the baseline down so "TV" sits centered in the 44pt-tall button.
    labelView.frame.origin.y += (initialFrame.height - labelView.font!.pointSize) / 2 - 4

    routePickerView = AVRoutePickerView(frame: initialFrame)
    routePickerView.alphaValue = 0.011

    containerView = NSView(frame: initialFrame)
    containerView.addSubview(labelView)
    containerView.addSubview(routePickerView)

    let window = NSWindow(
      contentRect: initialFrame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isReleasedWhenClosed = false
    window.ignoresMouseEvents = false
    window.contentView = containerView

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
    let bounds = NSRect(origin: .zero, size: screenRect.size)
    containerView.frame = bounds
    routePickerView.frame = bounds
    labelView.frame = bounds
    labelView.frame.origin.y += (bounds.height - labelView.font!.pointSize) / 2 - 4
  }

  func setVisible(_ visible: Bool) {
    if visible {
      overlayWindow.orderFront(nil)
    } else {
      overlayWindow.orderOut(nil)
    }
  }
}
