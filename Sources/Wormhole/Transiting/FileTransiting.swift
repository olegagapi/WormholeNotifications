import Foundation

/// A transiting strategy that stores messages as files in a directory.
///
/// Each message is stored as a separate file with a `.message` extension.
/// This is the default and most compatible transiting strategy.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor FileTransiting: TransitingStrategy {

    /// The file extension used for message files.
    public static let fileExtension = "message"

    /// The directory where message files are stored.
    public let directory: URL

    private let fileManager: FileManager

    /// Creates a file transiting strategy with the specified directory.
    ///
    /// - Parameter directory: The directory URL where messages will be stored.
    public init(directory: URL) {
        self.directory = directory
        self.fileManager = FileManager.default
    }

    /// Creates a file transiting strategy for an app group.
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

        do {
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            throw WormholeError.writeFailed(error)
        }
    }

    public func read(for identifier: MessageIdentifier) async throws -> Data? {
        let fileURL = fileURL(for: identifier)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw WormholeError.readFailed(error)
        }
    }

    public func delete(for identifier: MessageIdentifier) async throws {
        let fileURL = fileURL(for: identifier)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw WormholeError.writeFailed(error)
        }
    }

    public func deleteAll() async throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )

            for fileURL in contents {
                if fileURL.pathExtension == Self.fileExtension {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            throw WormholeError.writeFailed(error)
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
