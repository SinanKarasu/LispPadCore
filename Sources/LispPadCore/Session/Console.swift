import Combine
import Foundation

public final class Console: ObservableObject, CustomStringConvertible {
    @Published public private(set) var content: [ConsoleOutput] = []

    public init() {}

    public var isEmpty: Bool {
        self.content.isEmpty
    }

    public func append(output: ConsoleOutput) {
        let max = UserSettings.standard.maxConsoleHistory
        while self.content.count >= (max + 50) {
            self.content.removeFirst(self.content.count - max)
        }
        if let last = self.content.last,
           last.kind == .output,
           last.text.last == "\n" {
            self.content[self.content.count - 1].text = String(last.text.dropLast())
        }
        self.content.append(output)
    }

    public func print(_ string: String) {
        if self.content.isEmpty {
            self.append(output: .output(string))
        } else if let last = self.content.last, last.kind == .output {
            if last.text.count < 1000 {
                self.content[self.content.count - 1].text += string
            } else if string.first == "\n" {
                self.append(output: .output(String(string.dropFirst())))
            } else if last.text.last == "\n" {
                let text = String(self.content[self.content.count - 1].text.dropLast())
                self.content[self.content.count - 1].text = text
                self.append(output: .output(string))
            } else {
                self.append(output: .output(string))
            }
        } else {
            self.append(output: .output(string))
        }
    }

    public func removeLast() {
        guard !self.content.isEmpty else {
            return
        }
        self.content.removeLast()
    }

    public func reset() {
        self.content.removeAll()
    }

    public var lastOutputID: UUID? {
        self.content.last?.id
    }

    public var description: String {
        self.content
            .filter { $0.kind != .empty }
            .map(\.description)
            .joined(separator: "\n")
    }
}
