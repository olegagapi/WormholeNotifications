import Testing
import Foundation
@testable import Wormhole

@Suite("CoordinatedFileTransiting Tests")
struct CoordinatedFileTransitingTests {

    // MARK: - Test Helpers

    func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WormholeCoordTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Basic Operations Tests

    @Test("Write and read round-trip")
    func writeReadRoundTrip() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let originalData = Data("Coordinated Hello!".utf8)

        try await transiting.write(originalData, for: "greeting")
        let readData = try await transiting.read(for: "greeting")

        #expect(readData == originalData)
    }

    @Test("Read returns nil for non-existent message")
    func readNonExistent() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let data = try await transiting.read(for: "nonExistent")

        #expect(data == nil)
    }

    @Test("Delete removes message")
    func deleteRemoves() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        try await transiting.write(Data("test".utf8), for: "toDelete")
        try await transiting.delete(for: "toDelete")

        let data = try await transiting.read(for: "toDelete")
        #expect(data == nil)
    }

    @Test("Delete all removes all messages")
    func deleteAllRemovesAll() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)

        try await transiting.write(Data("1".utf8), for: "msg1")
        try await transiting.write(Data("2".utf8), for: "msg2")

        try await transiting.deleteAll()

        #expect(try await transiting.read(for: "msg1") == nil)
        #expect(try await transiting.read(for: "msg2") == nil)
    }

    // MARK: - NSFileCoordinator Integration Tests

    @Test("Uses file coordination for writes")
    func fileCoordinationWrite() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let data = Data("coordinated write".utf8)

        // This should not throw and should use file coordination internally
        let result = try await transiting.write(data, for: "coordinated")
        #expect(result == true)

        // Verify the data was written correctly
        let readData = try await transiting.read(for: "coordinated")
        #expect(readData == data)
    }

    @Test("Uses file coordination for reads")
    func fileCoordinationRead() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let originalData = Data("to be coordinated".utf8)

        try await transiting.write(originalData, for: "toRead")

        // This should use file coordination internally
        let readData = try await transiting.read(for: "toRead")
        #expect(readData == originalData)
    }

    // MARK: - Concurrent Access Safety Tests

    @Test("Concurrent writes to same identifier")
    func concurrentWritesSameIdentifier() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let identifier: MessageIdentifier = "concurrent"

        // Perform many concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    try? await transiting.write(Data("value\(i)".utf8), for: identifier)
                }
            }
        }

        // Should have some value (last write wins, but safely)
        let finalData = try await transiting.read(for: identifier)
        #expect(finalData != nil)
    }

    @Test("Concurrent reads while writing")
    func concurrentReadsWhileWriting() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let identifier: MessageIdentifier = "readWrite"

        // Initial write
        try await transiting.write(Data("initial".utf8), for: identifier)

        // Concurrent reads and writes
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<10 {
                group.addTask {
                    try? await transiting.write(Data("write\(i)".utf8), for: identifier)
                }
            }

            // Readers
            for _ in 0..<10 {
                group.addTask {
                    _ = try? await transiting.read(for: identifier)
                }
            }
        }

        // Should complete without errors and have valid data
        let finalData = try await transiting.read(for: identifier)
        #expect(finalData != nil)
    }

    @Test("Multiple instances accessing same file")
    func multipleInstancesSameFile() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting1 = CoordinatedFileTransiting(directory: tempDir)
        let transiting2 = CoordinatedFileTransiting(directory: tempDir)

        let identifier: MessageIdentifier = "shared"
        let data1 = Data("from instance 1".utf8)
        let data2 = Data("from instance 2".utf8)

        // Write from first instance
        try await transiting1.write(data1, for: identifier)

        // Read from second instance
        let readBySecond = try await transiting2.read(for: identifier)
        #expect(readBySecond == data1)

        // Overwrite from second instance
        try await transiting2.write(data2, for: identifier)

        // Read from first instance
        let readByFirst = try await transiting1.read(for: identifier)
        #expect(readByFirst == data2)
    }

    // MARK: - Edge Cases

    @Test("Write large data with coordination")
    func writeLargeDataCoordinated() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)
        let largeData = Data(repeating: 0xCD, count: 500_000)

        try await transiting.write(largeData, for: "large")
        let readData = try await transiting.read(for: "large")

        #expect(readData == largeData)
    }

    @Test("Delete non-existent does not throw")
    func deleteNonExistentNoThrow() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let transiting = CoordinatedFileTransiting(directory: tempDir)

        // Should not throw
        try await transiting.delete(for: "nonExistent")
    }
}
