import Cocoa
import FlutterMacOS

/// Передаёт Dart системную настройку «Уменьшить прозрачность» (канал `app.beading/accessibility`).
/// Dart → macOS: `isReduceTransparencyEnabled` → Bool. macOS → Dart: `reduceTransparencyChanged` с Bool.
final class AccessibilityChannel {
  static let name = "app.beading/accessibility"

  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "isReduceTransparencyEnabled" {
        result(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod(
        "reduceTransparencyChanged",
        arguments: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
      )
    }
  }

  deinit {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
  }
}

class MainFlutterWindow: NSWindow {
  private var accessibilityChannel: AccessibilityChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    accessibilityChannel = AccessibilityChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
