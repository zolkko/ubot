import Foundation
import os

struct AppLogger {}

extension AppLogger {
    // Subsystem identifies your app, Category identifies the module
    private static var subsystem = Bundle.main.bundleIdentifier ?? "place.blumen.UbotPad"
    static let app = Logger(subsystem: subsystem, category: "App")
}
