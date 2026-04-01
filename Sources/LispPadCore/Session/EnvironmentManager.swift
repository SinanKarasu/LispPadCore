import Combine
import Foundation
import LispKit

public final class EnvironmentManager: ObservableObject, @unchecked Sendable {
    @Published private var bindingCountStorage: Int = 0
    @Published private var bindingNamesStorage: [String] = []

    public init() {}

    public var bindingCount: Int {
        self.bindingCountStorage
    }

    public var bindingNames: [String] {
        self.bindingNamesStorage
    }

    func add(symbol: Symbol) {
        self.add(identifier: symbol.identifier)
    }

    func add(identifier: String) {
        DispatchQueue.main.async {
            if Self.insert(identifier: identifier, into: &self.bindingNamesStorage) {
                self.bindingCountStorage += 1
            }
        }
    }

    func replaceBindings(with identifiers: [String]) {
        let uniqueSorted = Array(Set(identifiers)).sorted()
        DispatchQueue.main.sync {
            self.bindingNamesStorage = uniqueSorted
            self.bindingCountStorage = uniqueSorted.count
        }
    }

    @discardableResult
    private static func insert(identifier: String, into bindings: inout [String]) -> Bool {
        var low = 0
        var high = bindings.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let current = bindings[middle]
            if current < identifier {
                low = middle + 1
            } else if identifier < current {
                high = middle - 1
            } else {
                return false
            }
        }
        bindings.insert(identifier, at: low)
        return true
    }

    func reset() {
        DispatchQueue.main.sync {
            self.bindingNamesStorage.removeAll()
            self.bindingCountStorage = 0
        }
    }
}
