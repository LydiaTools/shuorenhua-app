import Foundation

enum ReplyMemory {
    private static let key = "confirmedReplyStyleExamplesV1"
    private static let maximumCount = 8

    static func load(defaults: UserDefaults = .standard) -> [String] {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func remember(_ raw: String, defaults: UserDefaults = .standard) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var values = load(defaults: defaults).filter { $0 != value }
        values.insert(String(value.prefix(1200)), at: 0)
        values = Array(values.prefix(maximumCount))
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: key) }
    }

    static func clear(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }
}
