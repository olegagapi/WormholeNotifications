import Foundation

/// Configuration options for a Wormhole instance.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public struct Configuration: Sendable {

    /// The app group identifier used for shared storage between the app and its extensions.
    ///
    /// This must match an app group configured in your app's entitlements.
    public let appGroupIdentifier: String

    /// An optional subdirectory within the app group container for storing messages.
    ///
    /// If `nil`, messages are stored directly in the app group container root.
    public let directory: String?

    /// The strategy used for persisting messages between processes.
    public let transitingStrategy: TransitingType

    /// The format used for serializing messages.
    public let serializationFormat: SerializationFormat

    /// Creates a configuration with the specified options.
    ///
    /// - Parameters:
    ///   - appGroupIdentifier: The app group identifier for shared storage.
    ///   - directory: Optional subdirectory for message storage.
    ///   - transitingStrategy: The persistence strategy. Defaults to `.file`.
    ///   - serializationFormat: The serialization format. Defaults to `.json`.
    public init(
        appGroupIdentifier: String,
        directory: String? = nil,
        transitingStrategy: TransitingType = .file,
        serializationFormat: SerializationFormat = .json
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.directory = directory
        self.transitingStrategy = transitingStrategy
        self.serializationFormat = serializationFormat
    }
}

/// The strategy for persisting messages between processes.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public enum TransitingType: Sendable, Equatable {

    /// Store messages as individual files in the shared container.
    ///
    /// This is the default and most compatible option.
    case file

    /// Store messages as files using `NSFileCoordinator` for safe concurrent access.
    ///
    /// Use this when you need coordinated file access between multiple processes
    /// that may read/write simultaneously.
    case coordinatedFile

    /// Store messages in a shared `UserDefaults` suite.
    ///
    /// This can be simpler but has size limitations and may not be suitable
    /// for large messages.
    case userDefaults
}

/// The format used for serializing messages.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public enum SerializationFormat: Sendable, Equatable {

    /// JSON serialization using `JSONEncoder`/`JSONDecoder`.
    ///
    /// This is the default format and provides good compatibility and debuggability.
    case json
}
