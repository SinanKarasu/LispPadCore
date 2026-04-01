import Combine
import Foundation
import LispKit

public final class LibraryManager: ObservableObject, @unchecked Sendable {
    public struct LibraryProxy: Hashable, CustomStringConvertible, Identifiable, Sendable {
        public let name: String
        public let isLoaded: Bool
        public let state: String

        public var id: String { self.name }

        fileprivate init(scanned: String) {
            self.name = scanned
            self.isLoaded = false
            self.state = "found"
        }

        fileprivate init(loaded: Library) {
            self.name = loaded.name.description
            self.isLoaded = true
            self.state = loaded.state.description
        }

        public var components: [String] {
            let pieces = self.name[
                self.name.index(after: self.name.startIndex)..<self.name.index(before: self.name.endIndex)
            ].split(separator: " ")
            return pieces.map(String.init)
        }

        public var description: String {
            self.name
        }
    }

    @Published public private(set) var libraries: [LibraryProxy] = []
    private weak var fileHandler: FileHandler?

    public init() {}

    public var libraryNames: [String] {
        self.libraries.map(\.name)
    }

    public var loadedLibraryCount: Int {
        self.libraries.filter(\.isLoaded).count
    }

    func attachFileHandler(_ fileHandler: FileHandler) {
        self.fileHandler = fileHandler
    }

    func proxy(for library: Library) -> LibraryProxy {
        .init(loaded: library)
    }

    func add(library: Library) {
        self.add(proxy: .init(loaded: library))
    }

    func add(proxy: LibraryProxy) {
        let name = proxy.name
        var low = 0
        var high = self.libraries.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let current = self.libraries[middle].name
            switch name.localizedStandardCompare(current) {
            case .orderedDescending:
                low = middle + 1
            case .orderedAscending:
                high = middle - 1
            default:
                self.libraries[middle] = proxy
                return
            }
        }
        self.libraries.insert(proxy, at: low)
    }

    func updatedLibraries() -> [LibraryProxy] {
        var updated = self.libraries.filter(\.isLoaded)

        func addIfNew(_ scanned: String) {
            let proxy = LibraryProxy(scanned: "(" + scanned + ")")
            let name = proxy.name
            var low = 0
            var high = updated.count - 1
            while low <= high {
                let middle = (low + high) / 2
                let current = updated[middle].name
                switch name.localizedStandardCompare(current) {
                case .orderedDescending:
                    low = middle + 1
                case .orderedAscending:
                    high = middle - 1
                default:
                    return
                }
            }
            updated.insert(proxy, at: low)
        }

        for library in self.scanLibraryTrees() {
            addIfNew(library)
        }
        return updated
    }

    public func scheduleLibraryUpdate() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else {
                return
            }
            let updatedLibraries = self.updatedLibraries()
            DispatchQueue.main.async {
                self.libraries = updatedLibraries
            }
        }
    }

    public func updateLibraries() {
        self.libraries = self.updatedLibraries()
    }

    private func scanLibraryTrees() -> Set<String> {
        let fileManager = Foundation.FileManager.default
        var result: Set<String> = []
        guard let rootURLs = self.fileHandler?.librarySearchUrls else {
            return result
        }

        func scan(url: URL, name: String?) {
            guard let items = try? fileManager.contentsOfDirectory(atPath: url.path) else {
                return
            }
            for item in items {
                var itemURL = url.appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        scan(url: itemURL, name: name == nil ? item : name! + " " + item)
                    } else if itemURL.pathExtension == "sld" {
                        itemURL.deletePathExtension()
                        if let name {
                            result.insert(name + " " + itemURL.lastPathComponent)
                        } else {
                            result.insert(itemURL.lastPathComponent)
                        }
                    }
                }
            }
        }

        for rootURL in rootURLs {
            scan(url: rootURL, name: nil)
        }
        return result
    }

    func reset() {
        self.fileHandler = nil
        self.libraries.removeAll()
    }
}
