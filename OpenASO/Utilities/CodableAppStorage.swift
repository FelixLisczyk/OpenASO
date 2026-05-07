import SwiftUI

@propertyWrapper
struct CodableAppStorage<Value: Codable>: DynamicProperty {
    @AppStorage private var data: Data

    private let defaultValue: Value
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var wrappedValue: Value {
        get {
            guard let decoded = try? decoder.decode(Value.self, from: data) else {
                return defaultValue
            }

            return decoded
        }
        nonmutating set {
            guard let encoded = try? encoder.encode(newValue) else {
                data = (try? encoder.encode(defaultValue)) ?? Data()
                return
            }

            data = encoded
        }
    }

    init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults? = nil) {
        self.defaultValue = defaultValue
        let defaultData = (try? JSONEncoder().encode(defaultValue)) ?? Data()
        let resolvedStore = store ?? .standard

        if let storageValue = resolvedStore.string(forKey: key),
           let migratedData = storageValue.data(using: .utf8),
           (try? JSONDecoder().decode(Value.self, from: migratedData)) != nil {
            resolvedStore.set(migratedData, forKey: key)
        }

        self._data = AppStorage(wrappedValue: defaultData, key, store: store)
    }

    init(_ key: String, defaultValue: Value, store: UserDefaults? = nil) {
        self.defaultValue = defaultValue
        let defaultData = (try? JSONEncoder().encode(defaultValue)) ?? Data()
        let resolvedStore = store ?? .standard

        if let storageValue = resolvedStore.string(forKey: key),
           let migratedData = storageValue.data(using: .utf8),
           (try? JSONDecoder().decode(Value.self, from: migratedData)) != nil {
            resolvedStore.set(migratedData, forKey: key)
        }

        self._data = AppStorage(wrappedValue: defaultData, key, store: store)
    }
}
