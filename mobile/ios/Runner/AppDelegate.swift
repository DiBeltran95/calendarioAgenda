import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Muestra las notificaciones locales también con la app abierta y
    // entrega el toque a flutter_local_notifications.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // Refresco en segundo plano (respaldo cuando no hay push del servidor).
    // iOS exige registrar la tarea antes de terminar el arranque; el
    // identificador está también en Info.plist (BGTaskSchedulerPermittedIdentifiers)
    // y en lib/features/notifications/refresco_fondo.dart.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.agendaservi.refrescar-avisos",
      earliestBeginInSeconds: NSNumber(value: 30 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
