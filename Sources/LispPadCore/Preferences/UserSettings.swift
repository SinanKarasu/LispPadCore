import Combine
import Foundation

public final class UserSettings: ObservableObject, @unchecked Sendable {
    private enum Key {
        static let foldersOnICloud = "Folders.iCloud"
        static let foldersOnDevice = "Folders.device"
        static let consoleInlineGraphics = "Console.inlineGraphics"
        static let consoleCustomFormatting = "Console.customFormatting"
        static let maxConsoleHistory = "Console.maxConsoleHistory"
        static let balancedParenthesis = "Console.balancedParenthesis"
        static let maxCommandHistory = "Console.maxCommandHistory"
        static let logSeverityFilter = "Log.severityFilter"
        static let logMessageFilter = "Log.messageFilter"
        static let logFilterTags = "Log.filterTags"
        static let logFilterMessages = "Log.filterMessages"
        static let logCommands = "Log.commands"
        static let logGarbageCollection = "Log.garbageCollection"
        static let logMaxHistory = "Log.maxHistory"
        static let indentSize = "Editor.indentSize"
        static let rememberLastEditedFile = "Editor.rememberLastEditedFile"
        static let maxRecentFiles = "Editor.maxRecentFiles"
        static let maxStackSize = "Interpreter.maxStackSize"
        static let maxCallTrace = "Interpreter.maxCallTrace"
    }

    public static let standard = UserSettings()

    @Published public var foldersOnICloud: Bool {
        didSet { UserDefaults.standard.set(self.foldersOnICloud, forKey: Key.foldersOnICloud) }
    }

    @Published public var foldersOnDevice: Bool {
        didSet { UserDefaults.standard.set(self.foldersOnDevice, forKey: Key.foldersOnDevice) }
    }

    @Published public var consoleInlineGraphics: Bool {
        didSet { UserDefaults.standard.set(self.consoleInlineGraphics, forKey: Key.consoleInlineGraphics) }
    }

    @Published public var consoleCustomFormatting: Bool {
        didSet { UserDefaults.standard.set(self.consoleCustomFormatting, forKey: Key.consoleCustomFormatting) }
    }

    @Published public var maxConsoleHistory: Int {
        didSet { UserDefaults.standard.set(self.maxConsoleHistory, forKey: Key.maxConsoleHistory) }
    }

    @Published public var balancedParenthesis: Bool {
        didSet { UserDefaults.standard.set(self.balancedParenthesis, forKey: Key.balancedParenthesis) }
    }

    @Published public var maxCommandHistory: Int {
        didSet { UserDefaults.standard.set(self.maxCommandHistory, forKey: Key.maxCommandHistory) }
    }

    @Published public var logSeverityFilter: Severity {
        didSet {
            UserDefaults.standard.set(self.logSeverityFilter.description, forKey: Key.logSeverityFilter)
        }
    }

    @Published public var logMessageFilter: String {
        didSet { UserDefaults.standard.set(self.logMessageFilter, forKey: Key.logMessageFilter) }
    }

    @Published public var logFilterTags: Bool {
        didSet { UserDefaults.standard.set(self.logFilterTags, forKey: Key.logFilterTags) }
    }

    @Published public var logFilterMessages: Bool {
        didSet { UserDefaults.standard.set(self.logFilterMessages, forKey: Key.logFilterMessages) }
    }

    @Published public var logCommands: Bool {
        didSet { UserDefaults.standard.set(self.logCommands, forKey: Key.logCommands) }
    }

    @Published public var logGarbageCollection: Bool {
        didSet {
            UserDefaults.standard.set(self.logGarbageCollection, forKey: Key.logGarbageCollection)
        }
    }

    @Published public var logMaxHistory: Int {
        didSet { UserDefaults.standard.set(self.logMaxHistory, forKey: Key.logMaxHistory) }
    }

    @Published public var indentSize: Int {
        didSet { UserDefaults.standard.set(self.indentSize, forKey: Key.indentSize) }
    }

    @Published public var rememberLastEditedFile: Bool {
        didSet {
            UserDefaults.standard.set(self.rememberLastEditedFile, forKey: Key.rememberLastEditedFile)
        }
    }

    @Published public var maxRecentFiles: Int {
        didSet { UserDefaults.standard.set(self.maxRecentFiles, forKey: Key.maxRecentFiles) }
    }

    @Published public var maxStackSize: Int {
        didSet { UserDefaults.standard.set(self.maxStackSize, forKey: Key.maxStackSize) }
    }

    @Published public var maxCallTrace: Int {
        didSet { UserDefaults.standard.set(self.maxCallTrace, forKey: Key.maxCallTrace) }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.foldersOnICloud = Self.bool(forKey: Key.foldersOnICloud, default: false, in: defaults)
        self.foldersOnDevice = Self.bool(forKey: Key.foldersOnDevice, default: true, in: defaults)
        self.consoleInlineGraphics = Self.bool(forKey: Key.consoleInlineGraphics, default: false, in: defaults)
        self.consoleCustomFormatting = Self.bool(forKey: Key.consoleCustomFormatting, default: true, in: defaults)
        self.maxConsoleHistory = Self.int(forKey: Key.maxConsoleHistory, default: 250, in: defaults)
        self.balancedParenthesis = Self.bool(forKey: Key.balancedParenthesis, default: true, in: defaults)
        self.maxCommandHistory = Self.int(forKey: Key.maxCommandHistory, default: 50, in: defaults)
        self.logSeverityFilter = Severity(defaults.string(forKey: Key.logSeverityFilter) ?? "Debug")
        self.logMessageFilter = defaults.string(forKey: Key.logMessageFilter) ?? ""
        self.logFilterTags = Self.bool(forKey: Key.logFilterTags, default: true, in: defaults)
        self.logFilterMessages = Self.bool(forKey: Key.logFilterMessages, default: true, in: defaults)
        self.logCommands = Self.bool(forKey: Key.logCommands, default: false, in: defaults)
        self.logGarbageCollection = Self.bool(forKey: Key.logGarbageCollection, default: false, in: defaults)
        self.logMaxHistory = Self.int(forKey: Key.logMaxHistory, default: 500, in: defaults)
        self.indentSize = Self.int(forKey: Key.indentSize, default: 2, in: defaults)
        self.rememberLastEditedFile = Self.bool(forKey: Key.rememberLastEditedFile, default: true, in: defaults)
        self.maxRecentFiles = Self.int(forKey: Key.maxRecentFiles, default: 20, in: defaults)
        self.maxStackSize = Self.int(forKey: Key.maxStackSize, default: 500, in: defaults)
        self.maxCallTrace = Self.int(forKey: Key.maxCallTrace, default: 25, in: defaults)
    }

    private static func bool(forKey key: String, default defaultValue: Bool, in defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private static func int(forKey key: String, default defaultValue: Int, in defaults: UserDefaults) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        let value = defaults.integer(forKey: key)
        return value == 0 ? defaultValue : value
    }
}
