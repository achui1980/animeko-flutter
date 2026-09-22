import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    // Ignore SIGPIPE so a write() to a closed socket/pipe returns EPIPE to the
    // caller instead of killing the whole process.
    //
    // macOS's default SIGPIPE action is to terminate, with no crash dialog and
    // no diagnostic report - the window simply vanishes. The standalone Dart VM
    // guards against this in dart::bin::Platform::Initialize(), but the Flutter
    // engine only calls BootstrapDartIo(), so Flutter desktop apps keep the
    // lethal default. We hit it via libmpv/FFmpeg writing to the local rqbit
    // HTTP stream after rqbit closes the connection mid-playback.
    signal(SIGPIPE, SIG_IGN)
    super.init()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
