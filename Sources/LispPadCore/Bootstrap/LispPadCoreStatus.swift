import Foundation

public enum LispPadCoreStatus {
    public static let bootstrapFileCount = 22

    public static let bootstrapSummary =
        "LispPadCore now includes a shared LispKit-backed session runtime for iPadOS, macOS, and visionOS-oriented work."

    public static let bootstrapComponents: [String] = [
        "LispPadDocument",
        "DirectoryTracker",
        "FileExtensions",
        "FileObserver",
        "PortableURL",
        "IntField",
        "OptionalScrollView",
        "Appearance",
        "UserSettings",
        "HistoryManager",
        "SessionLog",
        "ConsoleOutput",
        "Console",
        "EnvironmentManager",
        "LibraryManager",
        "Interpreter",
        "AsyncResult",
        "Characters",
        "TaskSerializer",
        "ThreadUtil",
        "Zoomable"
    ]
}
