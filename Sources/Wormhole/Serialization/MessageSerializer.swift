import Foundation

/// A protocol for encoding and decoding messages.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public protocol MessageSerializer: Sendable {

    /// Encodes a value to `Data`.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: The encoded data.
    /// - Throws: An error if encoding fails.
    func encode<T: Encodable>(_ value: T) throws -> Data

    /// Decodes a value from `Data`.
    ///
    /// - Parameter data: The data to decode.
    /// - Returns: The decoded value.
    /// - Throws: An error if decoding fails.
    func decode<T: Decodable>(from data: Data) throws -> T
}
