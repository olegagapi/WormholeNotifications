import Foundation

/// A transiting strategy that stores messages in a shared UserDefaults suite.
///
/// This strategy is simpler than file-based transiting but has size limitations
/// and may not be suitable for large messages.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor UserDefaultsTransiting: TransitingStrategy {

    /// The key prefix used for all wormhole messages.
    public static let keyPrefix = "wormhole."

    /// The UserDefaults suite name.
    public let suiteName: String

    private let userDefaults: UserDefaults

    /// Creates a UserDefaults transiting strategy with the specified suite name.
    ///
    /// - Parameter suiteName: The suite name for the UserDefaults.
    ///   This should typically be an app group identifier.
    /// - Note: If the suite cannot be created, operations will fail silently.
    public init(suiteName: String) {
        self.suiteName = suiteName
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }

    /// Creates a UserDefaults transiting strategy for an app group.
    ///
    /// - Parameter appGroupIdentifier: The app group identifier to use as the suite name.
    public init(appGroupIdentifier: String) {
        self.suiteName = appGroupIdentifier
        self.userDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
    }

    // MARK: - TransitingStrategy

    @discardableResult
    public func write(_ data: Data, for identifier: MessageIdentifier) async throws -> Bool {
        let key = prefixedKey(for: identifier)
        userDefaults.set(data, forKey: key)
        return true
    }

    public func read(for identifier: MessageIdentifier) async throws -> Data? {
        let key = prefixedKey(for: identifier)
        return userDefaults.data(forKey: key)
    }

    public func delete(for identifier: MessageIdentifier) async throws {
        let key = prefixedKey(for: identifier)
        userDefaults.removeObject(forKey: key)
    }

    public func deleteAll() async throws {
        let dictionary = userDefaults.dictionaryRepresentation()

        for key in dictionary.keys where key.hasPrefix(Self.keyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private Helpers

    private func prefixedKey(for identifier: MessageIdentifier) -> String {
        "\(Self.keyPrefix)\(identifier.rawValue)"
    }
}
