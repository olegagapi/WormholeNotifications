import Testing
import Foundation
@testable import Wormhole

@Suite("WormholeError Tests")
struct WormholeErrorTests {

    // MARK: - Error Cases

    @Test("Invalid app group identifier error")
    func invalidAppGroupIdentifier() {
        let error = WormholeError.invalidAppGroupIdentifier("com.example.invalid")
        if case .invalidAppGroupIdentifier(let identifier) = error {
            #expect(identifier == "com.example.invalid")
        } else {
            Issue.record("Expected invalidAppGroupIdentifier case")
        }
    }

    @Test("Directory creation failed error")
    func directoryCreationFailed() {
        let underlyingError = NSError(domain: "test", code: 1)
        let error = WormholeError.directoryCreationFailed(underlyingError)
        if case .directoryCreationFailed(let wrapped) = error {
            #expect((wrapped as NSError).domain == "test")
        } else {
            Issue.record("Expected directoryCreationFailed case")
        }
    }

    @Test("Serialization failed error")
    func serializationFailed() {
        let underlyingError = NSError(domain: "encoding", code: 2)
        let error = WormholeError.serializationFailed(underlyingError)
        if case .serializationFailed(let wrapped) = error {
            #expect((wrapped as NSError).code == 2)
        } else {
            Issue.record("Expected serializationFailed case")
        }
    }

    @Test("Deserialization failed error")
    func deserializationFailed() {
        let underlyingError = NSError(domain: "decoding", code: 3)
        let error = WormholeError.deserializationFailed(underlyingError)
        if case .deserializationFailed(let wrapped) = error {
            #expect((wrapped as NSError).code == 3)
        } else {
            Issue.record("Expected deserializationFailed case")
        }
    }

    @Test("Write failed error")
    func writeFailed() {
        let underlyingError = NSError(domain: "io", code: 4)
        let error = WormholeError.writeFailed(underlyingError)
        if case .writeFailed(let wrapped) = error {
            #expect((wrapped as NSError).code == 4)
        } else {
            Issue.record("Expected writeFailed case")
        }
    }

    @Test("Read failed error")
    func readFailed() {
        let underlyingError = NSError(domain: "io", code: 5)
        let error = WormholeError.readFailed(underlyingError)
        if case .readFailed(let wrapped) = error {
            #expect((wrapped as NSError).code == 5)
        } else {
            Issue.record("Expected readFailed case")
        }
    }

    @Test("Notification registration failed error")
    func notificationRegistrationFailed() {
        let error = WormholeError.notificationRegistrationFailed("test.notification")
        if case .notificationRegistrationFailed(let name) = error {
            #expect(name == "test.notification")
        } else {
            Issue.record("Expected notificationRegistrationFailed case")
        }
    }

    // MARK: - LocalizedError Conformance

    @Test("Error description for invalid app group")
    func errorDescriptionInvalidAppGroup() {
        let error = WormholeError.invalidAppGroupIdentifier("group.test")
        #expect(error.errorDescription?.contains("group.test") == true)
    }

    @Test("Error description for directory creation failed")
    func errorDescriptionDirectoryCreation() {
        let error = WormholeError.directoryCreationFailed(NSError(domain: "", code: 0))
        #expect(error.errorDescription?.contains("directory") == true || error.errorDescription?.contains("Directory") == true)
    }

    @Test("Error description for serialization failed")
    func errorDescriptionSerialization() {
        let error = WormholeError.serializationFailed(NSError(domain: "", code: 0))
        #expect(error.errorDescription?.contains("serial") == true || error.errorDescription?.contains("Serial") == true || error.errorDescription?.contains("encod") == true)
    }

    @Test("Error description for deserialization failed")
    func errorDescriptionDeserialization() {
        let error = WormholeError.deserializationFailed(NSError(domain: "", code: 0))
        #expect(error.errorDescription?.contains("serial") == true || error.errorDescription?.contains("Serial") == true || error.errorDescription?.contains("decod") == true)
    }

    // MARK: - Equatable (for testing convenience)

    @Test("Same error cases are distinguishable")
    func errorCaseDistinction() {
        let error1 = WormholeError.invalidAppGroupIdentifier("test")
        let error2 = WormholeError.serializationFailed(NSError(domain: "", code: 0))

        // Pattern matching should distinguish them
        var isInvalidAppGroup = false
        if case .invalidAppGroupIdentifier = error1 {
            isInvalidAppGroup = true
        }
        #expect(isInvalidAppGroup)

        var isSerialization = false
        if case .serializationFailed = error2 {
            isSerialization = true
        }
        #expect(isSerialization)
    }
}
