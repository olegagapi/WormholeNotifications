import Foundation

/// A message serializer that uses JSON encoding.
///
/// This is the default serializer for Wormhole, providing human-readable
/// message storage and broad compatibility with Codable types.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public struct JSONSerializer: MessageSerializer {

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a JSON serializer with default encoder/decoder settings.
    public init() {
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Creates a JSON serializer with custom encoder and decoder.
    ///
    /// - Parameters:
    ///   - encoder: A custom JSON encoder.
    ///   - decoder: A custom JSON decoder.
    public init(encoder: JSONEncoder, decoder: JSONDecoder) {
        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    public func decode<T: Decodable>(from data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}
