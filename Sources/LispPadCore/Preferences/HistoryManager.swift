import Combine
import Foundation

public final class HistoryManager: ObservableObject, @unchecked Sendable {
    private static let commandHistoryUserDefaultsKey = "Console.history"
    private static let filesHistoryUserDefaultsKey = "Files.history"
    private static let currentFileUserDefaultsKey = "Files.current"
    private static let searchHistoryUserDefaultsKey = "Files.searchHistory"
    private static let favoritesUserDefaultsKey = "Files.favorites"
    private static let maxFavoritesUserDefaultsKey = "Files.maxFavorites"
    private static let maxFavoritesMax = 50

    private let encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    @Published public var commandHistory: [String] = {
        UserDefaults.standard.object(forKey: HistoryManager.commandHistoryUserDefaultsKey) as? [String]
            ?? ["(+ 2 3)"]
    }()

    @Published public var currentlyEdited: PortableURL? = {
        if let data = UserDefaults.standard.value(forKey: HistoryManager.currentFileUserDefaultsKey) as? Data,
           let portableURL = try? PropertyListDecoder().decode(PortableURL?.self, from: data) {
            return portableURL.itemExists ? portableURL : nil
        }
        return nil
    }()

    @Published public var recentlyEdited: [PortableURL] = {
        if let data = UserDefaults.standard.value(forKey: HistoryManager.filesHistoryUserDefaultsKey) as? Data,
           let portableURLs = try? PropertyListDecoder().decode([PortableURL].self, from: data) {
            return portableURLs.filter { $0.itemExists && !$0.isInTrash }
        }
        return []
    }()

    @Published public var favoriteFiles: [PortableURL] = {
        if let data = UserDefaults.standard.value(forKey: HistoryManager.favoritesUserDefaultsKey) as? Data,
           let portableURLs = try? PropertyListDecoder().decode([PortableURL].self, from: data) {
            return portableURLs.filter { $0.itemExists && !$0.isInTrash }
        }
        return []
    }()

    @Published public var searchHistory: [SearchHistoryEntry] = {
        if let data = UserDefaults.standard.value(forKey: HistoryManager.searchHistoryUserDefaultsKey) as? Data,
           let entries = try? PropertyListDecoder().decode([SearchHistoryEntry].self, from: data) {
            return entries
        }
        return []
    }()

    let documentsTracker = DirectoryTracker(PortableURL.Base.documents.url)
    let icloudTracker = DirectoryTracker(PortableURL.Base.icloud.url)

    @discardableResult
    private func mutateOnMain<T>(_ proc: () -> T) -> T {
        doOnMainThread(proc: proc)
    }

    public init() {
        self.documentsTracker?.onDelete = { [weak self] url in
            self?.mutateOnMain {
                let portableURL = PortableURL(url: url)
                _ = self?.removeRecentFile(portableURL)
                _ = self?.removeFavorite(portableURL)
                if portableURL == self?.currentlyEdited {
                    self?.trackCurrentFile(nil)
                }
            }
        }
        self.documentsTracker?.onMove = { [weak self] oldURL, newURL in
            self?.mutateOnMain {
                let oldPortableURL = PortableURL(url: oldURL)
                let newPortableURL = PortableURL(url: newURL)
                let keepTracking = newPortableURL.itemExists && !newPortableURL.isInTrash
                if let index = self?.removeRecentFile(oldPortableURL), keepTracking {
                    self?.recentlyEdited.insert(newPortableURL, at: index)
                }
                if let index = self?.removeFavorite(oldPortableURL), keepTracking {
                    self?.favoriteFiles.insert(newPortableURL, at: index)
                }
                if oldPortableURL == self?.currentlyEdited {
                    self?.trackCurrentFile(keepTracking ? newURL : nil)
                }
            }
        }
        self.icloudTracker?.onDelete = { [weak self] url in
            self?.mutateOnMain {
                let portableURL = PortableURL(url: url)
                _ = self?.removeRecentFile(portableURL)
                _ = self?.removeFavorite(portableURL)
                if portableURL == self?.currentlyEdited {
                    self?.trackCurrentFile(nil)
                }
            }
        }
        self.icloudTracker?.onMove = { [weak self] oldURL, newURL in
            self?.mutateOnMain {
                let oldPortableURL = PortableURL(url: oldURL)
                let newPortableURL = PortableURL(url: newURL)
                let keepTracking = newPortableURL.itemExists && !newPortableURL.isInTrash
                if let index = self?.removeRecentFile(oldPortableURL), keepTracking {
                    self?.recentlyEdited.insert(newPortableURL, at: index)
                }
                if let index = self?.removeFavorite(oldPortableURL), keepTracking {
                    self?.favoriteFiles.insert(newPortableURL, at: index)
                }
                if oldPortableURL == self?.currentlyEdited, keepTracking {
                    self?.trackCurrentFile(newURL)
                }
            }
        }
    }

    deinit {
        if let filePresenter = self.documentsTracker {
            NSFileCoordinator.removeFilePresenter(filePresenter)
        }
        if let filePresenter = self.icloudTracker {
            NSFileCoordinator.removeFilePresenter(filePresenter)
        }
    }

    public func setupFilePresenters() {
        self.mutateOnMain {
            if let filePresenter = self.documentsTracker {
                NSFileCoordinator.addFilePresenter(filePresenter)
            }
            if let filePresenter = self.icloudTracker {
                NSFileCoordinator.addFilePresenter(filePresenter)
            }
        }
    }

    public func suspendFilePresenters() {
        self.mutateOnMain {
            if let filePresenter = self.documentsTracker {
                NSFileCoordinator.removeFilePresenter(filePresenter)
            }
            if let filePresenter = self.icloudTracker {
                NSFileCoordinator.removeFilePresenter(filePresenter)
            }
        }
    }

    public var maxCommandHistory: Int {
        UserSettings.standard.maxCommandHistory
    }

    private var commandHistoryRequiresSaving = false

    @discardableResult
    public func addCommandEntry(_ input: String) -> Bool {
        self.mutateOnMain {
            let string = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !string.isEmpty else {
                return false
            }
            if self.commandHistory.isEmpty || string != self.commandHistory.first {
                self.commandHistory.removeAll { $0 == string }
                self.commandHistory.insert(string, at: 0)
                if self.maxCommandHistory < self.commandHistory.count {
                    self.commandHistory.removeLast(self.commandHistory.count - self.maxCommandHistory)
                }
                self.commandHistoryRequiresSaving = true
                return true
            }
            return false
        }
    }

    public func removeCommandEntry() {
        self.mutateOnMain {
            guard !self.commandHistory.isEmpty else {
                return
            }
            self.commandHistory.removeFirst()
            self.commandHistoryRequiresSaving = true
        }
    }

    public func saveCommandHistory() {
        guard self.commandHistoryRequiresSaving else {
            return
        }
        UserDefaults.standard.set(self.commandHistory, forKey: Self.commandHistoryUserDefaultsKey)
        self.commandHistoryRequiresSaving = false
    }

    public var maxFilesHistory: Int {
        UserSettings.standard.maxRecentFiles
    }

    private var filesHistoryRequiresSaving = false

    public func trackCurrentFile(_ url: URL?) {
        self.mutateOnMain {
            if let url {
                let portableURL = PortableURL(url: url)
                if portableURL != self.currentlyEdited {
                    self.currentlyEdited = portableURL
                    UserDefaults.standard.set(
                        try? self.encoder.encode(self.currentlyEdited),
                        forKey: Self.currentFileUserDefaultsKey
                    )
                }
            } else if self.currentlyEdited != nil {
                self.currentlyEdited = nil
                UserDefaults.standard.set(
                    try? self.encoder.encode(self.currentlyEdited),
                    forKey: Self.currentFileUserDefaultsKey
                )
            }
        }
    }

    public func trackRecentFile(_ url: URL) {
        self.mutateOnMain {
            guard !Foundation.FileManager.default.isInTrash(url) else {
                return
            }
            let portableURL = PortableURL(url: url)
            _ = self.removeRecentFile(portableURL)
            self.recentlyEdited.insert(portableURL, at: 0)
            if self.maxFilesHistory < self.recentlyEdited.count {
                self.recentlyEdited.removeLast(self.recentlyEdited.count - self.maxFilesHistory)
            }
            self.filesHistoryRequiresSaving = true
        }
    }

    @discardableResult
    public func removeRecentFile(_ portableURL: PortableURL) -> Int? {
        self.mutateOnMain {
            for index in self.recentlyEdited.indices where self.recentlyEdited[index] == portableURL {
                self.recentlyEdited.remove(at: index)
                self.filesHistoryRequiresSaving = true
                return index
            }
            return nil
        }
    }

    public func verifyRecentFiles() {
        self.mutateOnMain {
            let recentFiles = self.recentlyEdited.filter(\.fileExists)
            if recentFiles.count < self.recentlyEdited.count {
                self.recentlyEdited = recentFiles
                self.filesHistoryRequiresSaving = true
            }
        }
    }

    public func saveFilesHistory() {
        guard self.filesHistoryRequiresSaving else {
            return
        }
        UserDefaults.standard.set(
            try? self.encoder.encode(self.recentlyEdited),
            forKey: Self.filesHistoryUserDefaultsKey
        )
        self.filesHistoryRequiresSaving = false
    }

    public var maxSearchHistory: Int { 20 }

    private var searchHistoryRequiresSaving = false

    public func rememberSearch(_ entry: SearchHistoryEntry) {
        self.mutateOnMain {
            self.removeRecentSearch(entry)
            self.searchHistory.insert(entry, at: 0)
            if self.maxSearchHistory < self.searchHistory.count {
                self.searchHistory.removeLast(self.searchHistory.count - self.maxSearchHistory)
            }
            self.searchHistoryRequiresSaving = true
        }
    }

    public func removeRecentSearch(_ entry: SearchHistoryEntry) {
        self.mutateOnMain {
            for index in self.searchHistory.indices where self.searchHistory[index] == entry {
                self.searchHistory.remove(at: index)
                self.searchHistoryRequiresSaving = true
                return
            }
        }
    }

    public func saveSearchHistory() {
        guard self.searchHistoryRequiresSaving else {
            return
        }
        UserDefaults.standard.set(
            try? self.encoder.encode(self.searchHistory),
            forKey: Self.searchHistoryUserDefaultsKey
        )
        self.searchHistoryRequiresSaving = false
    }

    public private(set) var maxFavorites: Int = {
        let maxCount = UserDefaults.standard.integer(forKey: HistoryManager.maxFavoritesUserDefaultsKey)
        return maxCount == 0 ? 8 : maxCount
    }()

    private var favoritesRequiresSaving = false

    public func isFavorite(_ url: URL?) -> Bool {
        guard let portableURL = PortableURL(url) else {
            return false
        }
        return self.favoriteFiles.contains(portableURL)
    }

    public func canBeFavorite(_ url: URL?) -> Bool {
        guard let portableURL = PortableURL(url) else {
            return false
        }
        return portableURL.base != .application
    }

    public func toggleFavorite(_ url: URL?) {
        self.mutateOnMain {
            guard let url else {
                return
            }
            let portableURL = PortableURL(url: url)
            if self.removeFavorite(portableURL) == nil {
                self.favoriteFiles.insert(portableURL, at: 0)
                if self.maxFavorites < self.favoriteFiles.count {
                    self.favoriteFiles.removeLast(self.favoriteFiles.count - self.maxFavorites)
                }
                self.favoritesRequiresSaving = true
            }
        }
    }

    public func registerFavorite(_ url: URL) {
        self.mutateOnMain {
            let portableURL = PortableURL(url: url)
            _ = self.removeFavorite(portableURL)
            self.favoriteFiles.insert(portableURL, at: 0)
            if self.maxFavorites < self.favoriteFiles.count {
                self.favoriteFiles.removeLast(self.favoriteFiles.count - self.maxFavorites)
            }
            self.favoritesRequiresSaving = true
        }
    }

    @discardableResult
    public func removeFavorite(_ portableURL: PortableURL) -> Int? {
        self.mutateOnMain {
            for index in self.favoriteFiles.indices where self.favoriteFiles[index] == portableURL {
                self.favoriteFiles.remove(at: index)
                self.favoritesRequiresSaving = true
                return index
            }
            return nil
        }
    }

    public func setMaxFavoritesCount(to max: Int) {
        self.mutateOnMain {
            guard max > 0 && max <= Self.maxFavoritesMax else {
                return
            }
            UserDefaults.standard.set(max, forKey: Self.maxFavoritesUserDefaultsKey)
            self.maxFavorites = max
            if max < self.favoriteFiles.count {
                self.favoriteFiles.removeLast(self.favoriteFiles.count - max)
                self.favoritesRequiresSaving = true
            }
        }
    }

    public func verifyFavorites() {
        self.mutateOnMain {
            let favorites = self.favoriteFiles.filter(\.fileExists)
            if favorites.count < self.favoriteFiles.count {
                self.favoriteFiles = favorites
                self.favoritesRequiresSaving = true
            }
        }
    }

    public func saveFavorites() {
        guard self.favoritesRequiresSaving else {
            return
        }
        UserDefaults.standard.set(
            try? self.encoder.encode(self.favoriteFiles),
            forKey: Self.favoritesUserDefaultsKey
        )
        self.favoritesRequiresSaving = false
    }

    public func verifyFileLists() {
        self.mutateOnMain {
            self.verifyRecentFiles()
            self.verifyFavorites()
        }
    }
}

public struct SearchHistoryEntry: Hashable, Codable, CustomStringConvertible {
    public let searchText: String
    public let replaceText: String?

    public init(searchText: String, replaceText: String? = nil) {
        self.searchText = searchText
        self.replaceText = replaceText
    }

    public var searchOnly: Bool {
        self.replaceText == nil
    }

    public var description: String {
        if let replaceText {
            return "\(self.searchText) ▶︎ \(replaceText)"
        }
        return self.searchText
    }
}
