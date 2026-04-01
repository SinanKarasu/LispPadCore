import Combine
import Foundation
import LispKit

public final class EnvironmentManager: ObservableObject, @unchecked Sendable {
    @Published private var bindingNamesStorage: [String] = []

    public init() {}

    public var bindingCount: Int {
        self.bindingNamesStorage.count
    }

    public var bindingNames: [String] {
        self.bindingNamesStorage
    }

    func add(symbol: Symbol) {
        self.add(identifier: symbol.identifier)
    }

    func add(identifier: String) {
        Self.insert(identifier: identifier, into: &self.bindingNamesStorage)
    }

    private static func insert(identifier: String, into bindings: inout [String]) {
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
                low = middle
                break
            }
        }
        bindings.insert(identifier, at: low)
    }

    func reset() {
        self.bindingNamesStorage.removeAll()
    }
}
