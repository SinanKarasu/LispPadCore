import Foundation

public struct ConsoleOutput: CustomStringConvertible, Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case empty
        case info
        case command
        case output
        case error
        case result
    }

    public let id = UUID()
    public let kind: Kind
    public var text: String
    public let errorContext: ErrorContext?

    private init(kind: Kind, text: String, errorContext: ErrorContext? = nil) {
        self.kind = kind
        self.text = text
        self.errorContext = errorContext
    }

    public static var empty: ConsoleOutput {
        ConsoleOutput(kind: .empty, text: "")
    }

    public static func info(_ text: String) -> ConsoleOutput {
        ConsoleOutput(kind: .info, text: text)
    }

    public static func command(_ text: String) -> ConsoleOutput {
        ConsoleOutput(kind: .command, text: text)
    }

    public static func output(_ text: String) -> ConsoleOutput {
        ConsoleOutput(kind: .output, text: text)
    }

    public static func error(_ text: String, context: ErrorContext? = nil) -> ConsoleOutput {
        ConsoleOutput(kind: .error, text: text, errorContext: context)
    }

    public static func result(_ text: String = "") -> ConsoleOutput {
        ConsoleOutput(kind: .result, text: text)
    }

    public var logMessage: (Bool, String, String)? {
        switch self.kind {
        case .error:
            var result = self.text
            if let errorContext, !errorContext.description.isEmpty {
                result += "\n" + errorContext.description
            }
            if let type = errorContext?.type {
                return (true, "repl/err/\(type)", result)
            }
            return (true, "repl/err", result)
        case .result:
            return (false, "repl/res", self.text)
        default:
            return nil
        }
    }

    public var description: String {
        switch self.kind {
        case .empty:
            return ""
        case .info:
            return "info: " + self.text
        case .command:
            return "> " + self.text
        case .output:
            return self.text
        case .error:
            var result = "error: " + self.text
            if let errorContext, !errorContext.description.isEmpty {
                result += "\n" + errorContext.description
            }
            return result
        case .result:
            return self.text
        }
    }

    public var isError: Bool {
        self.kind == .error
    }

    public var isResult: Bool {
        switch self.kind {
        case .result, .error:
            return true
        default:
            return false
        }
    }
}

public struct ErrorContext: CustomStringConvertible, Equatable, Sendable {
    public let type: String?
    public let position: String?
    public let library: String?
    public let stackTrace: String?

    public init(type: String? = nil, position: String? = nil, library: String? = nil, stackTrace: String? = nil) {
        self.type = type
        self.position = position
        self.library = library
        self.stackTrace = stackTrace
    }

    public var description: String {
        var result = ""
        if let position {
            result += "position: \(position)"
        }
        if let library {
            if !result.isEmpty {
                result += "\n"
            }
            result += "library: \(library)"
        }
        if let stackTrace {
            if !result.isEmpty {
                result += "\n"
            }
            result += "stack trace: \(stackTrace)"
        }
        return result
    }
}
