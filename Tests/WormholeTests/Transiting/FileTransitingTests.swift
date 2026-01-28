import Testing
import Foundation
@testable import Wormhole

@Suite("FileTransiting Tests")
struct FileTransitingTests {

    // MARK: - Test Helpers

    /// Creates a temporary directory for testing
    func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WormholeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleans up a temporary directory
    func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Directory Creation Tests

    @Test("Creates directory if it doesn't exist")
    func createsDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WormholeTests-\(UUID().uuidString)")
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let data = Data("test".utf8)
        try await transiting.write(data, for: "test")

        #expect(FileManager.default.fileExists(atPath: tempDir.path))
    }

    @Test("Uses existing directory without error")
    func usesExistingDirectory() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let data = Data("test".utf8)
        let result = try await transiting.write(data, for: "test")

        #expect(result == true)
    }

    // MARK: - File Path Generation Tests

    @Test("Generates correct file path with .message extension")
    func filePathGeneration() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let data = Data("test".utf8)
        try await transiting.write(data, for: "myMessage")

        let expectedPath = tempDir.appendingPathComponent("myMessage.message")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    @Test("Handles identifiers with special characters")
    func identifierWithSpecialChars() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let data = Data("test".utf8)

        // Should handle dots in identifier
        try await transiting.write(data, for: "com.example.message")

        let expectedPath = tempDir.appendingPathComponent("com.example.message.message")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    // MARK: - Write/Read Round-trip Tests

    @Test("Write and read round-trip")
    func writeReadRoundTrip() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let originalData = Data("Hello, Wormhole!".utf8)

        try await transiting.write(originalData, for: "greeting")
        let readData = try await transiting.read(for: "greeting")

        #expect(readData == originalData)
    }

    @Test("Write overwrites existing message")
    func writeOverwrites() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let identifier: MessageIdentifier = "counter"

        try await transiting.write(Data("first".utf8), for: identifier)
        try await transiting.write(Data("second".utf8), for: identifier)

        let readData = try await transiting.read(for: identifier)
        #expect(readData == Data("second".utf8))
    }

    @Test("Write returns true on success")
    func writeReturnsTrue() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let result = try await transiting.write(Data("test".utf8), for: "test")

        #expect(result == true)
    }

    @Test("Read returns nil for non-existent message")
    func readNonExistent() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let data = try await transiting.read(for: "nonExistent")

        #expect(data == nil)
    }

    @Test("Write and read binary data")
    func writeReadBinaryData() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])

        try await transiting.write(binaryData, for: "binary")
        let readData = try await transiting.read(for: "binary")

        #expect(readData == binaryData)
    }

    @Test("Write and read large data")
    func writeReadLargeData() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let largeData = Data(repeating: 0xAB, count: 1_000_000) // 1MB

        try await transiting.write(largeData, for: "large")
        let readData = try await transiting.read(for: "large")

        #expect(readData == largeData)
    }

    // MARK: - Delete Individual Message Tests

    @Test("Delete removes message file")
    func deleteRemovesFile() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        try await transiting.write(Data("test".utf8), for: "toDelete")

        // Verify file exists
        let filePath = tempDir.appendingPathComponent("toDelete.message")
        #expect(FileManager.default.fileExists(atPath: filePath.path))

        // Delete and verify removal
        try await transiting.delete(for: "toDelete")
        #expect(!FileManager.default.fileExists(atPath: filePath.path))
    }

    @Test("Delete non-existent message does not throw")
    func deleteNonExistent() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)

        // Should not throw
        try await transiting.delete(for: "nonExistent")
    }

    @Test("Read returns nil after delete")
    func readAfterDelete() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        try await transiting.write(Data("test".utf8), for: "message")
        try await transiting.delete(for: "message")

        let data = try await transiting.read(for: "message")
        #expect(data == nil)
    }

    // MARK: - Delete All Messages Tests

    @Test("Delete all removes all message files")
    func deleteAllRemovesAll() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)

        // Write multiple messages
        try await transiting.write(Data("1".utf8), for: "msg1")
        try await transiting.write(Data("2".utf8), for: "msg2")
        try await transiting.write(Data("3".utf8), for: "msg3")

        // Delete all
        try await transiting.deleteAll()

        // Verify all are gone
        #expect(try await transiting.read(for: "msg1") == nil)
        #expect(try await transiting.read(for: "msg2") == nil)
        #expect(try await transiting.read(for: "msg3") == nil)
    }

    @Test("Delete all only removes .message files")
    func deleteAllOnlyMessageFiles() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create a non-message file
        let otherFile = tempDir.appendingPathComponent("other.txt")
        try "other content".write(to: otherFile, atomically: true, encoding: .utf8)

        let transiting = FileTransiting(directory: tempDir)
        try await transiting.write(Data("test".utf8), for: "message")

        try await transiting.deleteAll()

        // Message file should be gone
        #expect(try await transiting.read(for: "message") == nil)
        // Other file should remain
        #expect(FileManager.default.fileExists(atPath: otherFile.path))
    }

    @Test("Delete all on empty directory does not throw")
    func deleteAllEmptyDirectory() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)

        // Should not throw
        try await transiting.deleteAll()
    }

    // MARK: - Multiple Identifiers Tests

    @Test("Multiple identifiers are isolated")
    func multipleIdentifiersIsolated() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)

        try await transiting.write(Data("alpha".utf8), for: "a")
        try await transiting.write(Data("beta".utf8), for: "b")
        try await transiting.write(Data("gamma".utf8), for: "c")

        #expect(try await transiting.read(for: "a") == Data("alpha".utf8))
        #expect(try await transiting.read(for: "b") == Data("beta".utf8))
        #expect(try await transiting.read(for: "c") == Data("gamma".utf8))
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent writes to different identifiers")
    func concurrentWritesDifferentIdentifiers() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try? await transiting.write(Data("data\(i)".utf8), for: MessageIdentifier(rawValue: "msg\(i)"))
                }
            }
        }

        // Verify all writes succeeded
        for i in 0..<10 {
            let data = try await transiting.read(for: MessageIdentifier(rawValue: "msg\(i)"))
            #expect(data == Data("data\(i)".utf8))
        }
    }

    @Test("Concurrent reads")
    func concurrentReads() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = FileTransiting(directory: tempDir)
        let testData = Data("concurrent test".utf8)
        try await transiting.write(testData, for: "shared")

        await withTaskGroup(of: Data?.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try? await transiting.read(for: "shared")
                }
            }

            for await result in group {
                #expect(result == testData)
            }
        }
    }
}
