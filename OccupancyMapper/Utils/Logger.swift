import Foundation

enum LogLevel: String {
    case info    = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error   = "❌ ERROR"
    case performance = "⚡ PERF"
}

struct Logger {
    static var isEnabled: Bool = true
    
    static func info(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .info, file: file, function: function)
    }
    static func warning(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .warning, file: file, function: function)
    }
    static func error(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .error, file: file, function: function)
    }
    static func performance(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .performance, file: file, function: function)
    }
    
    private static func log(_ message: String, level: LogLevel, file: String, function: String) {
        guard isEnabled else { return }
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = formatted(Date())
        print("[\(timestamp)] \(level.rawValue) [\(filename)] \(function) → \(message)")
    }
    
    private static func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
