import Foundation

enum MojiBackupSettings {
    static let prefix = "moji."

    static func capture(from defaults: UserDefaults) throws -> (data: Data, count: Int) {
        let values = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix(prefix) }
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        return (data, values.count)
    }

    static func decode(_ data: Data) throws -> [String: Any] {
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let values = object as? [String: Any], values.keys.allSatisfy({ $0.hasPrefix(prefix) }) else {
            throw MojiBackupError.damaged
        }
        return values
    }

    static func restore(_ data: Data, into defaults: UserDefaults) throws {
        let values = try decode(data)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
    }
}
