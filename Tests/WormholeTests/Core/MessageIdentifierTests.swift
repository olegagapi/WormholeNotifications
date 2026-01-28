import Testing
import Foundation
@testable import Wormhole

@Suite("MessageIdentifier Tests")
struct MessageIdentifierTests {

    // MARK: - Initialization

    @Test("Initialize with raw value")
    func initWithRawValue() {
        let identifier = MessageIdentifier(rawValue: "test")
        #expect(identifier.rawValue == "test")
    }

    @Test("Initialize with string literal")
    func initWithStringLiteral() {
        let identifier: MessageIdentifier = "counter"
        #expect(identifier.rawValue == "counter")
    }

    @Test("Raw value preserves original string")
    func rawValuePreservation() {
        let original = "com.example.message.update"
        let identifier = MessageIdentifier(rawValue: original)
        #expect(identifier.rawValue == original)
    }

    // MARK: - Equality

    @Test("Equal identifiers")
    func equalIdentifiers() {
        let id1 = MessageIdentifier(rawValue: "test")
        let id2 = MessageIdentifier(rawValue: "test")
        #expect(id1 == id2)
    }

    @Test("Unequal identifiers")
    func unequalIdentifiers() {
        let id1 = MessageIdentifier(rawValue: "test1")
        let id2 = MessageIdentifier(rawValue: "test2")
        #expect(id1 != id2)
    }

    @Test("Case sensitive comparison")
    func caseSensitive() {
        let id1 = MessageIdentifier(rawValue: "Test")
        let id2 = MessageIdentifier(rawValue: "test")
        #expect(id1 != id2)
    }

    // MARK: - Hashing

    @Test("Equal identifiers have equal hash")
    func hashEquality() {
        let id1 = MessageIdentifier(rawValue: "test")
        let id2 = MessageIdentifier(rawValue: "test")
        #expect(id1.hashValue == id2.hashValue)
    }

    @Test("Can be used as dictionary key")
    func dictionaryKey() {
        var dict: [MessageIdentifier: Int] = [:]
        let identifier: MessageIdentifier = "counter"
        dict[identifier] = 42
        #expect(dict[identifier] == 42)
    }

    @Test("Can be used in Set")
    func setMembership() {
        var set: Set<MessageIdentifier> = []
        let id1: MessageIdentifier = "first"
        let id2: MessageIdentifier = "second"
        set.insert(id1)
        set.insert(id2)
        set.insert(id1) // Duplicate
        #expect(set.count == 2)
        #expect(set.contains(id1))
        #expect(set.contains(id2))
    }

    // MARK: - Sendable

    @Test("Is Sendable")
    func sendableConformance() async {
        let identifier: MessageIdentifier = "test"
        await Task {
            let _ = identifier.rawValue
        }.value
    }
}
