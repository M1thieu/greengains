import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // iOS stub for Android-only MethodChannels.
    // Tracking is not yet implemented on iOS — all service calls return safe
    // defaults so the UI renders and navigates without crashing or throwing
    // MissingPluginException. Wire real implementations in a future milestone.
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let foregroundChannel = FlutterMethodChannel(
      name: "greengains/foreground",
      binaryMessenger: controller.binaryMessenger
    )
    foregroundChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "startForegroundService",
           "stopForegroundService",
           "isForegroundServiceRunning",
           "isTrackingPaused",
           "pauseForegroundService",
           "resumeForegroundService",
           "flushSensorBuffers":
        // Return false — service not running, UI shows stopped state
        result(false)
      case "isIgnoringBatteryOptimizations":
        // iOS has no battery optimization concept — always "fine"
        result(true)
      case "requestLocationPermission",
           "requestIgnoreBatteryOptimizations":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Sensor trigger channel: Flutter is the listener, iOS never pushes.
    // Register so setMethodCallHandler on the Dart side doesn't throw.
    let _ = FlutterMethodChannel(
      name: "greengains/sensor_trigger",
      binaryMessenger: controller.binaryMessenger
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
