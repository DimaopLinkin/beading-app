import Cocoa
import FlutterMacOS

/// Передаёт Dart файлы `.biser`, которые открыли двойным щелчком или перетаскиванием на значок
/// (канал `app.beading/incoming_files`). Пути копятся, пока Dart не скажет `ready`.
final class IncomingFilesChannel {
  static let name = "app.beading/incoming_files"

  private var channel: FlutterMethodChannel?
  private var pending: [String] = []
  private var ready = false

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      if call.method == "ready" {
        self.ready = true
        self.flush()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func open(_ paths: [String]) {
    pending.append(contentsOf: paths)
    flush()
  }

  private func flush() {
    guard ready, let channel, !pending.isEmpty else { return }
    channel.invokeMethod("openFiles", arguments: pending)
    pending.removeAll()
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  static let incomingFiles = IncomingFilesChannel()

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    AppDelegate.incomingFiles.open(filenames)
    sender.reply(toOpenOrPrint: .success)
  }
}
