import Combine
import Foundation
import LispKit

public final class Interpreter: ObservableObject, ContextDelegate, @unchecked Sendable {
    public enum ReadingStatus: Equatable, CustomStringConvertible {
        case reject
        case accept
        case read(String)

        public var description: String {
            switch self {
            case .reject:
                return "reject"
            case .accept:
                return "accept"
            case .read(let string):
                return "read(\(string))"
            }
        }
    }

    final class Context: LispKit.Context {
        init(delegate: ContextDelegate) {
            super.init(
                delegate: delegate,
                implementationName: LispKitContext.implementationName,
                implementationVersion: LispKitContext.implementationVersion,
                commandLineArguments: CommandLine.arguments,
                initialHomePath: PortableURL.Base.documents.url?.path ?? PortableURL.Base.icloud.url?.path,
                includeInternalResources: true,
                includeDocumentPath: "LispKit",
                assetPath: nil,
                gcDelay: 5.0,
                features: Interpreter.lispKitFeatures,
                limitStack: UserSettings.standard.maxStackSize * 1000
            )
        }
    }

    public static let lispKitFeatures: [String] = [
        "lisppad",
        "lisppad-core"
    ]

    @Published public private(set) var isReady = false
    @Published public private(set) var readingStatus: ReadingStatus = .reject
    @Published public private(set) var contentBatch: Int = 0

    public let console = Console()
    public let libManager = LibraryManager()
    public let envManager = EnvironmentManager()

    var context: Context?
    private var replEnvironmentName: String?

    private let readingCondition = NSCondition()
    private let serializer = TaskSerializer()

    public init() {
        self.serializer.schedule(task: self.initialize)
        self.serializer.start()
    }

    deinit {
        self.serializer.cancel()
        self.serializer.schedule(task: {})
    }

    public var libraryCount: Int {
        self.libManager.libraries.count
    }

    public var loadedLibraryCount: Int {
        self.libManager.loadedLibraryCount
    }

    public var bindingCount: Int {
        self.envManager.bindingCount
    }

    public func setReplEnvironment(named name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.replEnvironmentName = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    public func evaluate(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        DispatchQueue.main.async {
            self.console.append(output: .command(trimmed))
            self.completeContentBatch()
        }

        self.readingCondition.lock()
        defer {
            self.readingCondition.signal()
            self.readingCondition.unlock()
        }

        guard self.isReady else {
            if self.readingStatus == .accept {
                self.readingStatus = .read(trimmed)
                self.console.print(trimmed + "\n")
            }
            return
        }

        self.isReady = false
        self.readingStatus = .reject
        let replEnvironmentName = self.replEnvironmentName
        self.serializer.schedule { [weak self] in
            guard let self else {
                return
            }
            if UserSettings.standard.logCommands {
                SessionLog.standard.addLogEntry(
                    severity: .info,
                    tag: "repl/exec",
                    message: trimmed
                )
            }
            let result = self.execute { machine in
                try machine.eval(
                    str: trimmed,
                    sourceId: SourceManager.consoleSourceId,
                    in: self.replEnvironment(in: machine, named: replEnvironmentName),
                    as: "<repl>"
                )
            }
            if UserSettings.standard.logCommands {
                for output in result {
                    if let (isError, type, message) = output.logMessage {
                        SessionLog.standard.addLogEntry(
                            severity: isError ? .error : .info,
                            tag: type,
                            message: message
                        )
                    }
                }
            }
            self.append(result: result)
        }
    }

    public func evaluate(_ text: String, url: URL?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        self.readingCondition.lock()
        defer {
            self.readingCondition.signal()
            self.readingCondition.unlock()
        }
        guard self.isReady else {
            return
        }
        self.isReady = false
        self.readingStatus = .reject
        let replEnvironmentName = self.replEnvironmentName
        self.serializer.schedule { [weak self] in
            guard let self else {
                return
            }
            let result = self.execute { machine in
                var sourceID = SourceManager.consoleSourceId
                if let url {
                    sourceID = machine.context.sources.obtainSourceId(for: url)
                }
                return try machine.eval(
                    str: trimmed,
                    sourceId: sourceID,
                    in: self.replEnvironment(in: machine, named: replEnvironmentName),
                    as: url?.lastPathComponent ?? "<input>"
                )
            }
            self.append(result: result)
        }
    }

    public func load(_ url: URL) {
        self.readingCondition.lock()
        defer {
            self.readingCondition.signal()
            self.readingCondition.unlock()
        }
        guard self.isReady else {
            return
        }
        self.isReady = false
        self.readingStatus = .reject
        let replEnvironmentName = self.replEnvironmentName
        self.serializer.schedule { [weak self] in
            guard let self else {
                return
            }
            let result = self.execute { machine in
                try machine.eval(
                    file: url.absoluteURL.path,
                    in: self.replEnvironment(in: machine, named: replEnvironmentName),
                    as: url.lastPathComponent
                )
            }
            self.append(result: result)
        }
    }

    public func importLibrary(_ library: [String]) {
        self.readingCondition.lock()
        defer {
            self.readingCondition.signal()
            self.readingCondition.unlock()
        }
        guard self.isReady else {
            return
        }
        self.isReady = false
        self.readingStatus = .reject
        self.serializer.schedule { [weak self] in
            guard let self else {
                return
            }
            let result = self.execute { machine in
                try machine.context.environment.import(library)
                return .void
            }
            self.append(result: result)
        }
    }

    @discardableResult
    public func reset() -> Bool {
        guard self.isReady else {
            return false
        }
        self.replEnvironmentName = nil
        self.context = nil
        self.serializer.schedule(task: self.initialize)
        return true
    }

    public func clearConsole() {
        DispatchQueue.main.async {
            self.console.reset()
            self.completeContentBatch()
        }
    }

    public var isInitialized: Bool {
        self.context != nil
    }

    private func completeContentBatch() {
        self.contentBatch &+= 1
    }

    private func append(result: [ConsoleOutput]) {
        DispatchQueue.main.sync {
            self.isReady = true
            self.readingStatus = .accept
            for output in result {
                self.console.append(output: output)
            }
            self.completeContentBatch()
        }
    }

    private func replEnvironment(in machine: VirtualMachine, named name: String?) -> Env {
        guard let name else {
            return machine.context.global
        }
        let symbol = machine.context.symbols.intern(name)
        guard let expr = machine.context.environment[symbol] else {
            return machine.context.global
        }
        guard case .env(let environment) = expr else {
            return machine.context.global
        }
        return .global(environment)
    }

    private func initialize() {
        self.context = nil
        DispatchQueue.main.sync {
            self.isReady = false
            self.readingStatus = .reject
            self.console.reset()
            self.completeContentBatch()
        }
        self.libManager.reset()
        self.envManager.reset()

        let context = Context(delegate: self)
        context.evaluator.maxCallStack = UserSettings.standard.maxCallTrace

        if let rootURL = LispPadPackageResources.rootURL,
           context.fileHandler.isDirectory(atPath: rootURL.path) {
            _ = context.fileHandler.prependSearchPath(rootURL.path)
        }
        if let librariesURL = LispPadPackageResources.librariesURL,
           context.fileHandler.isDirectory(atPath: librariesURL.path) {
            _ = context.fileHandler.prependLibrarySearchPath(librariesURL.path)
        }
        if let assetsURL = LispPadPackageResources.assetsURL,
           context.fileHandler.isDirectory(atPath: assetsURL.path) {
            _ = context.fileHandler.prependAssetSearchPath(assetsURL.path)
        }

        if UserSettings.standard.foldersOnICloud,
           let librariesPath = PortableURL.Base.icloud.url?.appendingPathComponent("Libraries", isDirectory: true).path {
            _ = context.fileHandler.prependLibrarySearchPath(librariesPath)
        }
        if UserSettings.standard.foldersOnDevice,
           let librariesPath = PortableURL.Base.documents.url?.appendingPathComponent("Libraries", isDirectory: true).path {
            _ = context.fileHandler.prependLibrarySearchPath(librariesPath)
        }
        if UserSettings.standard.foldersOnICloud,
           let assetsPath = PortableURL.Base.icloud.url?.appendingPathComponent("Assets", isDirectory: true).path {
            _ = context.fileHandler.prependAssetSearchPath(assetsPath)
        }
        if UserSettings.standard.foldersOnDevice,
           let assetsPath = PortableURL.Base.documents.url?.appendingPathComponent("Assets", isDirectory: true).path {
            _ = context.fileHandler.prependAssetSearchPath(assetsPath)
        }
        if UserSettings.standard.foldersOnICloud,
           let homePath = PortableURL.Base.icloud.url?.path {
            _ = context.fileHandler.prependSearchPath(homePath)
        }
        if UserSettings.standard.foldersOnDevice,
           let homePath = PortableURL.Base.documents.url?.path {
            _ = context.fileHandler.prependSearchPath(homePath)
        }

        self.libManager.attachFileHandler(context.fileHandler)

        do {
            try context.bootstrap(forRepl: true)
        } catch {
            DispatchQueue.main.sync {
                self.console.append(output: .error("Failed to bootstrap LispKit", context: ErrorContext(stackTrace: error.localizedDescription)))
                self.isReady = true
                self.readingStatus = .accept
                self.completeContentBatch()
            }
            return
        }

        if let preludePath = context.fileHandler.filePath(forFile: "Prelude") ?? LispPadPackageResources.preludeURL?.path {
            do {
                _ = try context.evaluator.machine.eval(file: preludePath)
            } catch let error as RuntimeError {
                DispatchQueue.main.sync {
                    self.console.append(output: .error(self.errorMessage(error, in: context), context: self.errorLocation(error, in: context)))
                    self.isReady = true
                    self.readingStatus = .accept
                    self.completeContentBatch()
                }
                return
            } catch {
                DispatchQueue.main.sync {
                    self.console.append(output: .error(error.localizedDescription))
                    self.isReady = true
                    self.readingStatus = .accept
                    self.completeContentBatch()
                }
                return
            }
        }

        self.libManager.replaceLoadedLibraries(with: Array(context.libraries.loaded))
        self.envManager.replaceBindings(with: context.environment.boundSymbols.map(\.identifier))
        self.context = context
        self.libManager.scheduleLibraryUpdate()

        DispatchQueue.main.sync {
            self.console.append(output: .info("LispPadCore session ready"))
            self.console.append(output: .result("Try (+ 2 3), (map (lambda (x) (* x x)) '(1 2 3 4)), or (features)."))
            self.isReady = true
            self.readingStatus = .accept
            self.completeContentBatch()
        }
    }

    private func format(expr: Expr, in context: Context) -> String {
        if UserSettings.standard.consoleCustomFormatting,
           let string = try? context.formatter.format(
                "~S",
                config: context.formatter.replFormatConfig,
                locale: Locale.current,
                tabsize: UserSettings.standard.indentSize,
                linewidth: 80,
                arguments: [expr]
           ) {
            return string
        }
        return expr.description
    }

    private func execute(action: (VirtualMachine) throws -> Expr) -> [ConsoleOutput] {
        guard let context = self.context else {
            return [.error("Interpreter is not initialized")]
        }
        let result = context.evaluator.execute { machine in
            try action(machine)
        }
        if context.evaluator.exitTriggered {
            SessionLog.standard.addLogEntry(severity: .info, tag: "repl/exit", message: "Exit requested by evaluated program")
        }
        switch result {
        case .error(let error):
            return [.error(self.errorMessage(error, in: context), context: self.errorLocation(error, in: context))]
        case .void:
            return []
        case .values(let exprs):
            var message = ""
            var next = exprs
            while case .pair(let expression, let rest) = next {
                if message.isEmpty {
                    message = self.format(expr: expression, in: context)
                } else {
                    message += "\n" + self.format(expr: expression, in: context)
                }
                next = rest
            }
            context.update(withReplResult: result)
            return message.isEmpty ? [] : [.result(message)]
        default:
            context.update(withReplResult: result)
            return [.result(self.format(expr: result, in: context))]
        }
    }

    private func errorMessage(_ error: RuntimeError, in context: Context) -> String {
        error.printableDescription(
            context: context,
            typeOpen: "〚",
            typeClose: "〛 ",
            irritantHeader: "\n     • ",
            irritantSeparator: "\n     • ",
            positionHeader: nil,
            libraryHeader: nil,
            stackTraceHeader: nil
        )
    }

    private func errorLocation(_ error: RuntimeError, in context: Context) -> ErrorContext {
        var position: String?
        if !error.pos.isUnknown {
            if let filename = context.sources.sourcePath(for: error.pos.sourceId) {
                position = "\(error.pos.description):\(filename)"
            } else {
                position = error.pos.description
            }
        }
        let library = error.library?.description
        guard let stackTrace = error.stackTrace, !stackTrace.isEmpty else {
            return ErrorContext(type: error.descriptor.shortTypeDescription, position: position, library: library)
        }
        var result = ""
        var separator = ""
        if let callTrace = error.callTrace {
            for call in callTrace {
                result += separator + call
                separator = " ← "
            }
            if stackTrace.count > callTrace.count {
                result += separator
                if stackTrace.count == callTrace.count + 1 {
                    result += "+1 call"
                } else {
                    result += "+\(stackTrace.count - callTrace.count) calls"
                }
            }
        } else {
            for procedure in stackTrace {
                result += separator + procedure.name
                separator = " ← "
            }
        }
        return ErrorContext(
            type: error.descriptor.shortTypeDescription,
            position: position,
            library: library,
            stackTrace: result
        )
    }

    public func print(_ string: String) {
        DispatchQueue.main.async {
            self.console.print(string)
            self.completeContentBatch()
        }
    }

    public func read() -> String? {
        DispatchQueue.main.sync {
            self.readingStatus = .accept
        }
        self.readingCondition.lock()
        defer {
            self.readingCondition.signal()
            self.readingCondition.unlock()
        }
        while !self.isReady && self.readingStatus == .accept {
            self.readingCondition.wait()
        }
        if case .read(let text) = self.readingStatus {
            DispatchQueue.main.sync {
                self.readingStatus = .reject
            }
            return text + "\n"
        }
        DispatchQueue.main.sync {
            self.readingStatus = .reject
        }
        return nil
    }

    public func loaded(library lib: Library, by _: LispKit.LibraryManager) {
        guard self.context != nil else {
            return
        }
        let proxy = self.libManager.proxy(for: lib)
        DispatchQueue.main.async {
            self.libManager.add(proxy: proxy)
        }
    }

    public func bound(symbol: Symbol, in _: LispKit.Environment) {
        guard self.context != nil else {
            return
        }
        let identifier = symbol.identifier
        self.envManager.add(identifier: identifier)
    }

    public func garbageCollected(objectPool: ManagedObjectPool, time: Double, objectsBefore: Int) {
        guard UserSettings.standard.logGarbageCollection else {
            return
        }
        SessionLog.standard.addLogEntry(
            severity: .info,
            tag: "repl/gc/\(objectPool.cycles)",
            message: "collected \(objectsBefore - objectPool.numManagedObjects) objects in " +
                "\(String(format: "%.2f", time * 1000.0))ms; \(objectPool.numManagedObjects) remain"
        )
    }
}
