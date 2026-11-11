import Flutter
import UIKit

/// Передаёт Dart системную настройку «Уменьшить прозрачность» (канал `app.beading/accessibility`).
/// Dart → iOS: `isReduceTransparencyEnabled` → Bool. iOS → Dart: `reduceTransparencyChanged` с Bool.
final class AccessibilityChannel {
  static let name = "app.beading/accessibility"

  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "isReduceTransparencyEnabled" {
        result(UIAccessibility.isReduceTransparencyEnabled)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("reduceTransparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)
    }
  }

  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var accessibilityChannel: AccessibilityChannel?
  private var imageMasksChannel: ImageMasksChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AccessibilityChannel") {
      accessibilityChannel = AccessibilityChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ImageMasksChannel") {
      imageMasksChannel = ImageMasksChannel(messenger: registrar.messenger())
    }
  }
}
