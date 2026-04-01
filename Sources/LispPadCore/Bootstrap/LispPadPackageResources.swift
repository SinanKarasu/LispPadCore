import Foundation
import LispKit

enum LispPadPackageResources {
    private static func existingDirectoryURL(_ candidates: [URL?]) -> URL? {
        let fileManager = FileManager.default
        for candidate in candidates.compactMap({ $0 }) where fileManager.fileExists(atPath: candidate.path) {
            return candidate.resolvingSymlinksInPath()
        }
        return nil
    }

    static let rootURL: URL? = {
        preludeURL?.deletingLastPathComponent().resolvingSymlinksInPath()
    }()

    static let librariesURL: URL? = {
        if let bundledLibraries = Bundle.module.url(forResource: "Libraries", withExtension: nil) {
            return bundledLibraries.resolvingSymlinksInPath()
        }
        return existingDirectoryURL([
            LispKitContext.bundle?.resourceURL?.appendingPathComponent("Libraries", isDirectory: true)
        ])
    }()

    static let assetsURL: URL? = {
        if let bundledAssets = Bundle.module.url(forResource: "Assets", withExtension: nil) {
            return bundledAssets.resolvingSymlinksInPath()
        }
        return existingDirectoryURL([
            LispKitContext.bundle?.resourceURL?.appendingPathComponent("Assets", isDirectory: true)
        ])
    }()

    static let preludeURL: URL? = Bundle.module.url(
        forResource: "Prelude",
        withExtension: "scm"
    )
}
