import Testing
import Foundation
@testable import Wormhole

@Suite("UserDefaultsTransiting Tests")
struct UserDefaultsTransitingTests {

    // MARK: - Test Helpers

    /// Creates a unique suite name for isolated testing
    func createTestSuiteName() -> String {
        "WormholeTest-\(UUID().uuidString)"
    }

    /// Removes test UserDefaults suite
    func cleanupSuite(_ suiteName: String) {
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    // MARK: - Basic Write/Read Tests

    @Test("Write and read round-trip")
    func writeReadRoundTrip() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        let originalData = Data("Hello, UserDefaults!".utf8)

        try await transiting.write(originalData, for: "greeting")
        let readData = try await transiting.read(for: "greeting")

        #expect(readData == originalData)
    }

    @Test("Write returns true on success")
    func writeReturnsTrue() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        let result = try await transiting.write(Data("test".utf8), for: "test")

        #expect(result == true)
    }

    @Test("Read returns nil for non-existent message")
    func readNonExistent() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        let data = try await transiting.read(for: "nonExistent")

        #expect(data == nil)
    }

    @Test("Write overwrites existing message")
    func writeOverwrites() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)

        try await transiting.write(Data("first".utf8), for: "key")
        try await transiting.write(Data("second".utf8), for: "key")

        let readData = try await transiting.read(for: "key")
        #expect(readData == Data("second".utf8))
    }

    // MARK: - Key Prefix Isolation Tests

    @Test("Messages use wormhole key prefix")
    func keyPrefix() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        try await transiting.write(Data("test".utf8), for: "myKey")

        // The key should be prefixed to avoid collisions
        let defaults = UserDefaults(suiteName: suiteName)
        let prefixedKey = "wormhole.myKey"

        // Verify the prefixed key contains our data
        #expect(defaults?.data(forKey: prefixedKey) == Data("test".utf8))
    }

    @Test("Different identifiers are isolated")
    func isolatedIdentifiers() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)

        try await transiting.write(Data("alpha".utf8), for: "a")
        try await transiting.write(Data("beta".utf8), for: "b")

        #expect(try await transiting.read(for: "a") == Data("alpha".utf8))
        #expect(try await transiting.read(for: "b") == Data("beta".utf8))
    }

    @Test("Does not interfere with non-wormhole keys")
    func noInterference() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("external value", forKey: "externalKey")

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        try await transiting.write(Data("wormhole data".utf8), for: "internalKey")

        // External key should be unaffected
        #expect(defaults.string(forKey: "externalKey") == "external value")
    }

    // MARK: - Delete Operations Tests

    @Test("Delete removes message")
    func deleteRemoves() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        try await transiting.write(Data("test".utf8), for: "toDelete")
        try await transiting.delete(for: "toDelete")

        let data = try await transiting.read(for: "toDelete")
        #expect(data == nil)
    }

    @Test("Delete non-existent does not throw")
    func deleteNonExistent() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)

        // Should not throw
        try await transiting.delete(for: "nonExistent")
    }

    @Test("Delete all removes all wormhole messages")
    func deleteAllRemovesAll() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)

        try await transiting.write(Data("1".utf8), for: "msg1")
        try await transiting.write(Data("2".utf8), for: "msg2")
        try await transiting.write(Data("3".utf8), for: "msg3")

        try await transiting.deleteAll()

        #expect(try await transiting.read(for: "msg1") == nil)
        #expect(try await transiting.read(for: "msg2") == nil)
        #expect(try await transiting.read(for: "msg3") == nil)
    }

    @Test("Delete all preserves non-wormhole keys")
    func deleteAllPreservesOthers() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("keep me", forKey: "externalKey")

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        try await transiting.write(Data("delete me".utf8), for: "wormholeKey")

        try await transiting.deleteAll()

        // External key should remain
        #expect(defaults.string(forKey: "externalKey") == "keep me")
        // Wormhole key should be gone
        #expect(try await transiting.read(for: "wormholeKey") == nil)
    }

    // MARK: - Data Types Tests

    @Test("Write and read binary data")
    func writeReadBinary() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE])

        try await transiting.write(binaryData, for: "binary")
        let readData = try await transiting.read(for: "binary")

        #expect(readData == binaryData)
    }

    @Test("Write and read empty data")
    func writeReadEmpty() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)
        let emptyData = Data()

        try await transiting.write(emptyData, for: "empty")
        let readData = try await transiting.read(for: "empty")

        #expect(readData == emptyData)
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent writes to different keys")
    func concurrentWritesDifferentKeys() async throws {
        let suiteName = createTestSuiteName()
        defer { cleanupSuite(suiteName) }

        let transiting = UserDefaultsTransiting(suiteName: suiteName)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try? await transiting.write(
                        Data("data\(i)".utf8),
                        for: MessageIdentifier(rawValue: "key\(i)")
                    )
                }
            }
        }

        // Verify all writes succeeded
        for i in 0..<10 {
            let data = try await transiting.read(for: MessageIdentifier(rawValue: "key\(i)"))
            #expect(data == Data("data\(i)".utf8))
        }
    }
}
