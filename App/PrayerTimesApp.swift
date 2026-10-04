import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AppModel.registerBackgroundTask()
        return true
    }

    // Show notifications even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct PrayerTimesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { phase in
                    if phase == .active { Task { await model.onForeground() } }
                }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TimesView().tabItem { Label("Times", systemImage: "clock") }
            NotificationsView().tabItem { Label("Notifications", systemImage: "bell") }
            SettingsView().tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
