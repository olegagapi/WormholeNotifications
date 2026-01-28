import Foundation

/// A transiting strategy that stores messages as files using NSFileCoordinator.
///
/// This strategy provides safe concurrent access to message files from multiple
/// processes. Use this when you need coordinated file access between your app
/// and its extensions.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor CoordinatedFileTransiting: TransitingStrategy {

    /// The file extension used for message files.
    public static let fileExtension = "message"

    /// The directory where message files are stored.
    public let directory: URL

    private let fileManager: FileManager

    /// Creates a coordinated file transiting strategy with the specified directory.
    ///
    /// - Parameter directory: The directory URL where messages will be stored.
    public init(directory: URL) {
        self.directory = directory
        self.fileManager = FileManager.default
    }

    /// Creates a coordinated file transiting strategy for an app group.
    ///
    /// - Parameters:
    ///   - appGroupIdentifier: The app group identifier.
    ///   - subdirectory: Optional subdirectory within the app group container.
    /// - Throws: `WormholeError.invalidAppGroupIdentifier` if the app group cannot be accessed.
    public init(appGroupIdentifier: String, subdirectory: String? = nil) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw WormholeError.invalidAppGroupIdentifier(appGroupIdentifier)
        }

        if let subdirectory = subdirectory {
            self.directory = containerURL.appendingPathComponent(subdirectory)
        } else {
            self.directory = containerURL
        }

        self.fileManager = FileManager.default
    }

    // MARK: - TransitingStrategy

    @discardableResult
    public func write(_ data: Data, for identifier: MessageIdentifier) async throws -> Bool {
        try ensureDirectoryExists()

        let fileURL = fileURL(for: identifier)
        var coordinatorError: NSError?
        var writeError: Error?
        var success = false

        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(
            writingItemAt: fileURL,
            options: .forReplacing,
            error: &coordinatorError
        ) { url in
            do {
                try data.write(to: url, options: .atomic)
                success = true
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError {
            throw WormholeError.writeFailed(error)
        }

        if let error = writeError {
            throw WormholeError.writeFailed(error)
        }

        return success
    }

    public func read(for identifier: MessageIdentifier) async throws -> Data? {
        let fileURL = fileURL(for: identifier)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        var coordinatorError: NSError?
        var readError: Error?
        var result: Data?

        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinatorError
        ) { url in
            do {
                result = try Data(contentsOf: url)
            } catch {
                readError = error
            }
        }

        if let error = coordinatorError {
            throw WormholeError.readFailed(error)
        }

        if let error = readError {
            throw WormholeError.readFailed(error)
        }

        return result
    }

    public func delete(for identifier: MessageIdentifier) async throws {
        let fileURL = fileURL(for: identifier)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        var coordinatorError: NSError?
        var deleteError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(
            writingItemAt: fileURL,
            options: .forDeleting,
            error: &coordinatorError
        ) { url in
            do {
                try fileManager.removeItem(at: url)
            } catch {
                deleteError = error
            }
        }

        if let error = coordinatorError {
            throw WormholeError.writeFailed(error)
        }

        if let error = deleteError {
            throw WormholeError.writeFailed(error)
        }
    }

    public func deleteAll() async throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw WormholeError.readFailed(error)
        }

        for fileURL in contents where fileURL.pathExtension == Self.fileExtension {
            var coordinatorError: NSError?
            var deleteError: Error?

            let coordinator = NSFileCoordinator(filePresenter: nil)

            coordinator.coordinate(
                writingItemAt: fileURL,
                options: .forDeleting,
                error: &coordinatorError
            ) { url in
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    deleteError = error
                }
            }

            if let error = coordinatorError ?? deleteError {
                throw WormholeError.writeFailed(error)
            }
        }
    }

    // MARK: - Private Helpers

    private func fileURL(for identifier: MessageIdentifier) -> URL {
        directory.appendingPathComponent("\(identifier.rawValue).\(Self.fileExtension)")
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directory.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw WormholeError.directoryCreationFailed(error)
        }
    }
}
