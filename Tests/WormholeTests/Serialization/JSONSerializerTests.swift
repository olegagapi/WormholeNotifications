import Testing
import Foundation
@testable import Wormhole

@Suite("JSONSerializer Tests")
struct JSONSerializerTests {

    let serializer = JSONSerializer()

    // MARK: - Test Types

    struct SimpleMessage: Codable, Equatable, Sendable {
        let text: String
    }

    struct ComplexMessage: Codable, Equatable, Sendable {
        let id: Int
        let name: String
        let values: [Double]
        let metadata: [String: String]
    }

    struct DateMessage: Codable, Equatable, Sendable {
        let timestamp: Date
    }

    struct NestedMessage: Codable, Equatable, Sendable {
        struct Inner: Codable, Equatable, Sendable {
            let value: Int
        }
        let inner: Inner
        let array: [Inner]
    }

    struct OptionalMessage: Codable, Equatable, Sendable {
        let required: String
        let optional: String?
    }

    // MARK: - Encode Tests

    @Test("Encode simple message")
    func encodeSimple() throws {
        let message = SimpleMessage(text: "Hello, Wormhole!")
        let data = try serializer.encode(message)
        #expect(!data.isEmpty)
    }

    @Test("Encode complex message")
    func encodeComplex() throws {
        let message = ComplexMessage(
            id: 42,
            name: "Test",
            values: [1.0, 2.5, 3.14],
            metadata: ["key": "value"]
        )
        let data = try serializer.encode(message)
        #expect(!data.isEmpty)
    }

    @Test("Encode nested message")
    func encodeNested() throws {
        let message = NestedMessage(
            inner: .init(value: 1),
            array: [.init(value: 2), .init(value: 3)]
        )
        let data = try serializer.encode(message)
        #expect(!data.isEmpty)
    }

    @Test("Encode message with optional nil")
    func encodeOptionalNil() throws {
        let message = OptionalMessage(required: "test", optional: nil)
        let data = try serializer.encode(message)
        #expect(!data.isEmpty)
    }

    @Test("Encode message with optional value")
    func encodeOptionalValue() throws {
        let message = OptionalMessage(required: "test", optional: "present")
        let data = try serializer.encode(message)
        #expect(!data.isEmpty)
    }

    // MARK: - Decode Tests

    @Test("Decode simple message")
    func decodeSimple() throws {
        let original = SimpleMessage(text: "Hello, Wormhole!")
        let data = try serializer.encode(original)
        let decoded: SimpleMessage = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Decode complex message")
    func decodeComplex() throws {
        let original = ComplexMessage(
            id: 42,
            name: "Test",
            values: [1.0, 2.5, 3.14],
            metadata: ["key": "value"]
        )
        let data = try serializer.encode(original)
        let decoded: ComplexMessage = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Decode nested message")
    func decodeNested() throws {
        let original = NestedMessage(
            inner: .init(value: 1),
            array: [.init(value: 2), .init(value: 3)]
        )
        let data = try serializer.encode(original)
        let decoded: NestedMessage = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip String")
    func roundTripString() throws {
        let original = "Hello, World!"
        let data = try serializer.encode(original)
        let decoded: String = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip Int")
    func roundTripInt() throws {
        let original = 42
        let data = try serializer.encode(original)
        let decoded: Int = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip Double")
    func roundTripDouble() throws {
        let original = 3.14159
        let data = try serializer.encode(original)
        let decoded: Double = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip Bool")
    func roundTripBool() throws {
        let original = true
        let data = try serializer.encode(original)
        let decoded: Bool = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip Array")
    func roundTripArray() throws {
        let original = [1, 2, 3, 4, 5]
        let data = try serializer.encode(original)
        let decoded: [Int] = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip Dictionary")
    func roundTripDictionary() throws {
        let original = ["one": 1, "two": 2, "three": 3]
        let data = try serializer.encode(original)
        let decoded: [String: Int] = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip Date")
    func roundTripDate() throws {
        let original = DateMessage(timestamp: Date(timeIntervalSince1970: 1000000))
        let data = try serializer.encode(original)
        let decoded: DateMessage = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip UUID")
    func roundTripUUID() throws {
        let original = UUID()
        let data = try serializer.encode(original)
        let decoded: UUID = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Round-trip URL")
    func roundTripURL() throws {
        let original = URL(string: "https://example.com/path")!
        let data = try serializer.encode(original)
        let decoded: URL = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    // MARK: - Error Handling Tests

    @Test("Decode malformed data throws error")
    func decodeMalformed() {
        let malformedData = Data("not valid json".utf8)
        #expect(throws: Error.self) {
            let _: SimpleMessage = try serializer.decode(from: malformedData)
        }
    }

    @Test("Decode wrong type throws error")
    func decodeWrongType() throws {
        let original = SimpleMessage(text: "test")
        let data = try serializer.encode(original)
        #expect(throws: Error.self) {
            let _: ComplexMessage = try serializer.decode(from: data)
        }
    }

    @Test("Decode empty data throws error")
    func decodeEmptyData() {
        let emptyData = Data()
        #expect(throws: Error.self) {
            let _: SimpleMessage = try serializer.decode(from: emptyData)
        }
    }

    // MARK: - Edge Cases

    @Test("Encode empty string")
    func encodeEmptyString() throws {
        let original = ""
        let data = try serializer.encode(original)
        let decoded: String = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Encode empty array")
    func encodeEmptyArray() throws {
        let original: [Int] = []
        let data = try serializer.encode(original)
        let decoded: [Int] = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Encode unicode content")
    func encodeUnicode() throws {
        let original = SimpleMessage(text: "Hello \u{1F30D} World \u{1F680}")
        let data = try serializer.encode(original)
        let decoded: SimpleMessage = try serializer.decode(from: data)
        #expect(decoded == original)
    }

    @Test("Encode special characters")
    func encodeSpecialChars() throws {
        let original = SimpleMessage(text: "Line1\nLine2\tTabbed\"Quoted\"")
        let data = try serializer.encode(original)
        let decoded: SimpleMessage = try serializer.decode(from: data)
        #expect(decoded == original)
    }
}
