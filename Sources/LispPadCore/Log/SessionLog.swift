import Combine
import Foundation

public final class SessionLog: ObservableObject, @unchecked Sendable {
    public static let standard = SessionLog()

    private var maxLogEntries: Int
    private(set) var severityFilter: Severity
    private(set) var tagFilter: Bool
    private(set) var messageFilter: Bool
    private(set) var searchString: String
    private(set) var excludeSearch: Bool

    private var logEntries: [LogEntry] = []
    public private(set) var filteredLogEntries: [LogEntry] = []

    private let mutex = NSLock()

    @Published public private(set) var stateID: UInt64 = 0

    private init() {
        self.maxLogEntries = UserSettings.standard.logMaxHistory
        self.severityFilter = UserSettings.standard.logSeverityFilter
        self.searchString = Self.normalizeSearchString(UserSettings.standard.logMessageFilter)
        self.messageFilter = UserSettings.standard.logFilterMessages
        self.tagFilter = UserSettings.standard.logFilterTags
        self.excludeSearch = UserSettings.standard.logMessageFilter
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .starts(with: "-")
    }

    private func stateUpdated() {
        DispatchQueue.main.async {
            self.stateID &+= 1
        }
    }

    private static func normalizeSearchString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.starts(with: "-") || trimmed.starts(with: "\\") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    public func setMaxLogEntries(_ maxEntries: Int) {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        self.maxLogEntries = maxEntries
        self.filterLogEntries()
    }

    public func set(severity: Severity, search: String, tag: Bool, message: Bool) {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        self.severityFilter = severity
        self.searchString = Self.normalizeSearchString(search)
        self.tagFilter = tag
        self.messageFilter = message
        self.excludeSearch = search.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "-")
        self.filterLogEntries()
    }

    private func matchesFilter(_ logEntry: LogEntry) -> Bool {
        guard logEntry.severity.rawValue >= self.severityFilter.rawValue else {
            return false
        }
        guard !self.searchString.isEmpty else {
            return true
        }
        let matches: Bool
        if self.tagFilter && self.messageFilter {
            matches = logEntry.tag.hasPrefix(self.searchString) || logEntry.message.contains(self.searchString)
        } else if self.tagFilter {
            matches = logEntry.tag.hasPrefix(self.searchString)
        } else if self.messageFilter {
            matches = logEntry.message.contains(self.searchString)
        } else {
            matches = true
        }
        return self.excludeSearch ? !matches : matches
    }

    public func reapplyFilter() {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        self.filterLogEntries()
    }

    private func filterLogEntries() {
        self.filteredLogEntries = self.logEntries.filter(self.matchesFilter)
        self.stateUpdated()
    }

    public var filteredLogEntryCount: Int {
        self.filteredLogEntries.count
    }

    public func filteredLogEntry(at index: Int) -> LogEntry? {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        guard index >= 0 && index < self.filteredLogEntries.count else {
            return nil
        }
        return self.filteredLogEntries[index]
    }

    public func addLogEntry(time: Double? = nil, severity: Severity, tag: String, message: String) {
        let logEntry = LogEntry(time: time, severity: severity, tag: tag, message: message)
        self.mutex.lock()
        defer { self.mutex.unlock() }
        self.logEntries.append(logEntry)
        if self.matchesFilter(logEntry) {
            self.filteredLogEntries.append(logEntry)
        }
        if self.logEntries.count > self.maxLogEntries {
            let numToRemove = self.logEntries.count - self.maxLogEntries
            var numFilteredToRemove = 0
            for index in 0..<numToRemove {
                let logEntry = self.logEntries[index]
                if numFilteredToRemove < self.filteredLogEntries.count,
                   self.filteredLogEntries[numFilteredToRemove] === logEntry {
                    numFilteredToRemove += 1
                }
            }
            self.filteredLogEntries.removeFirst(numFilteredToRemove)
            self.logEntries.removeFirst(numToRemove)
        }
        self.stateUpdated()
    }

    public func clear(all: Bool = true) {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        self.filteredLogEntries.removeAll()
        guard !all else {
            self.logEntries.removeAll()
            self.stateUpdated()
            return
        }
        self.logEntries.removeAll(where: self.matchesFilter)
        self.stateUpdated()
    }

    public func export(withHeader header: Bool = true) -> String {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        var logfile = header ? "\"Date\",\"Severity\",\"Tag\",\"Message\"\n" : ""
        for logEntry in self.logEntries {
            logfile += logEntry.csvEncoded + "\n"
        }
        return logfile
    }

    public func exportMessages() -> String {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        return self.logEntries.map(\.message).joined(separator: "\n")
    }
}

public final class LogEntry {
    public let id = UUID()
    public let time: Date
    public let severity: Severity
    public let tag: String
    public let message: String
    public let messageLines: Int

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd\nHH:mm:ss"
        return formatter
    }()

    static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    init(time: Double?, severity: Severity, tag: String, message: String) {
        self.time = time.map(Date.init(timeIntervalSince1970:)) ?? Date()
        self.severity = severity
        self.tag = tag
        self.message = message
        var numberOfLines = 0
        var index = 0
        let string = message as NSString
        while index < string.length {
            index = NSMaxRange(string.lineRange(for: NSRange(location: index, length: 0)))
            numberOfLines += 1
        }
        self.messageLines = numberOfLines
    }

    public var timeString: String {
        Self.timeFormatter.string(from: self.time)
    }

    public var dateTimeString: String {
        Self.dateFormatter.string(from: self.time)
    }

    public var csvEncoded: String {
        "\"\(Self.csvDateFormatter.string(from: self.time))\"," +
        "\"\(self.severity.description)\"," +
        "\"\(self.tag.replacingOccurrences(of: "\"", with: "\"\""))\"," +
        "\"\(self.message.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

public enum Severity: UInt8, Codable, CustomStringConvertible {
    case debug
    case info
    case warning
    case error
    case fatal

    public init(_ string: String) {
        switch string {
        case "Info":
            self = .info
        case "Warning":
            self = .warning
        case "Error":
            self = .error
        case "Fatal":
            self = .fatal
        default:
            self = .debug
        }
    }

    public var description: String {
        switch self {
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .fatal:
            return "Fatal"
        }
    }
}
