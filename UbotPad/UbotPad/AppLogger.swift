import Foundation
import os


extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "place.blumen.UbotPad"
    
    static let app = Logger(subsystem: subsystem, category: "App")
}
