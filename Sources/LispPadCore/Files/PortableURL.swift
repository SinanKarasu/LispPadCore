import Foundation
import LispKit

public enum PortableURL: Hashable, Codable, Identifiable, CustomStringConvertible {
    public enum Base: Int, Codable, CustomStringConvertible, CaseIterable {
        case application = 0
        case documents = 1
        case icloud = 2
        case lispkit = 3
        case lisppad = 4

        public var url: URL? {
            switch self {
            case .application:
                return Self.applicationURL
            case .documents:
                return Self.documentsURL
            case .icloud:
                return Self.icloudURL
            case .lispkit:
                return Self.lispkitURL
            case .lisppad:
                return Self.lisppadURL
            }
        }

        public var path: String? {
            guard let path = url?.absoluteURL.path else {
                return nil
            }
            return path.hasSuffix("/") ? path : path + "/"
        }

        public var imageName: String {
            switch self {
            case .application:
                return "internaldrive"
            case .documents:
                #if os(macOS)
                return "desktopcomputer"
                #else
                return "ipad"
                #endif
            case .icloud:
                return "icloud"
            case .lispkit:
                return "building.columns"
            case .lisppad:
                return "building.columns.fill"
            }
        }

        public var description: String {
            switch self {
            case .application:
                return "Internal"
            case .documents:
                return "Documents"
            case .icloud:
                return "iCloud"
            case .lispkit:
                return "LispKit"
            case .lisppad:
                return "LispPad"
            }
        }

        private static let applicationURL = appSupportDirectory()
        private static let documentsURL = documentsDirectory()
        private static let icloudURL = icloudDirectory()
        private static let lispkitURL = { () -> URL? in
            guard let base = LispKitContext.bundle?.bundleURL.absoluteURL else {
                return nil
            }
            return URL(fileURLWithPath: LispKitContext.rootDirectory, relativeTo: base)
                .resolvingSymlinksInPath()
        }()
        private static let lisppadURL = LispPadPackageResources.rootURL

        static func icloudDirectory() -> URL? {
            Foundation.FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
                .resolvingSymlinksInPath()
        }

        static func documentsDirectory() -> URL? {
            try? Foundation.FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).resolvingSymlinksInPath()
        }

        static func appSupportDirectory() -> URL? {
            try? Foundation.FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).resolvingSymlinksInPath()
        }

        static func cacheDirectory() -> URL? {
            Foundation.FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        }
    }

    enum CodingKeys: CodingKey {
        case url
        case rel
        case base

        static let absolute: Set<CodingKeys> = [.url]
        static let relative: Set<CodingKeys> = [.rel, .base]
    }

    case absolute(URL)
    case relative(String, Base)

    public init?(_ url: URL?) {
        guard let url else {
            return nil
        }
        self.init(url: url)
    }

    public init(url: URL) {
        if let (rel, base) = Self.normalizeURL(url) {
            self = .relative(rel, base)
        } else {
            self = .absolute(url)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = Set(container.allKeys)
        switch keys {
        case CodingKeys.absolute:
            let url = try container.decode(URL.self, forKey: .url)
            if let (rel, base) = Self.normalizeURL(url) {
                self = .relative(rel, base)
            } else {
                self = .absolute(url)
            }
        case CodingKeys.relative:
            self = .relative(
                try container.decode(String.self, forKey: .rel),
                try container.decode(Base.self, forKey: .base)
            )
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "PortableURL coding broken")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .absolute(let url):
            try container.encode(url, forKey: .url)
        case .relative(let rel, let base):
            try container.encode(rel, forKey: .rel)
            try container.encode(base, forKey: .base)
        }
    }

    public var isRelative: Bool {
        switch self {
        case .absolute:
            return false
        case .relative:
            return true
        }
    }

    public var url: URL? {
        switch self {
        case .absolute(let url):
            return url
        case .relative(let rel, let base):
            guard let baseURL = base.url else {
                return nil
            }
            return URL(fileURLWithPath: rel, relativeTo: baseURL)
        }
    }

    public var id: String {
        switch self {
        case .absolute(let url):
            return url.absoluteString
        case .relative(let rel, let base):
            return "[\(base)] \(rel)"
        }
    }

    public var relativePath: String {
        switch self {
        case .absolute(let url):
            return url.path
        case .relative(let rel, _):
            return rel
        }
    }

    public var base: Base? {
        switch self {
        case .absolute:
            return nil
        case .relative(_, let base):
            return base
        }
    }

    public var baseURL: URL? {
        switch self {
        case .absolute(let url):
            return url.baseURL
        case .relative(_, let base):
            return base.url
        }
    }

    public var absoluteURL: URL? {
        url?.absoluteURL
    }

    public var absolutePath: String? {
        url?.absoluteURL.path
    }

    public var itemExists: Bool {
        guard let path = absolutePath else {
            return false
        }
        var isDirectory: ObjCBool = false
        return Foundation.FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    }

    public var fileExists: Bool {
        guard let path = absolutePath else {
            return false
        }
        var isDirectory: ObjCBool = false
        return Foundation.FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    public var directoryExists: Bool {
        guard let path = absolutePath else {
            return false
        }
        var isDirectory: ObjCBool = false
        return Foundation.FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    public var isInTrash: Bool {
        guard let absoluteURL else {
            return false
        }
        return Foundation.FileManager.default.isInTrash(absoluteURL)
    }

    public var mutable: Bool {
        switch self {
        case .absolute,
             .relative(_, .application),
             .relative(_, .documents),
             .relative(_, .icloud):
            return true
        default:
            return false
        }
    }

    public var description: String {
        id
    }

    private static func normalizeURL(_ url: URL) -> (String, Base)? {
        let normalizedPath = url.absoluteURL.resolvingSymlinksInPath().path
        for base in Base.allCases {
            if let basePath = base.path, normalizedPath.hasPrefix(basePath) {
                let start = normalizedPath.index(normalizedPath.startIndex, offsetBy: basePath.count)
                return (String(normalizedPath[start...]), base)
            }
        }
        return nil
    }
}

extension Foundation.FileManager {
    public func isInTrash(_ url: URL) -> Bool {
        url.path.contains("/.Trash/")
    }
}
