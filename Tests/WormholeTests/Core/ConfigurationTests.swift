import Testing
import Foundation
@testable import Wormhole

@Suite("Configuration Tests")
struct ConfigurationTests {

    // MARK: - Initialization

    @Test("Initialize with required parameters only")
    func initWithRequiredParams() {
        let config = Configuration(appGroupIdentifier: "group.com.example.app")
        #expect(config.appGroupIdentifier == "group.com.example.app")
        #expect(config.directory == nil)
        #expect(config.transitingStrategy == .file)
        #expect(config.serializationFormat == .json)
    }

    @Test("Initialize with all parameters")
    func initWithAllParams() {
        let config = Configuration(
            appGroupIdentifier: "group.com.example.app",
            directory: "messages",
            transitingStrategy: .coordinatedFile,
            serializationFormat: .json
        )
        #expect(config.appGroupIdentifier == "group.com.example.app")
        #expect(config.directory == "messages")
        #expect(config.transitingStrategy == .coordinatedFile)
        #expect(config.serializationFormat == .json)
    }

    @Test("Initialize with custom directory")
    func initWithCustomDirectory() {
        let config = Configuration(
            appGroupIdentifier: "group.test",
            directory: "custom/path"
        )
        #expect(config.directory == "custom/path")
    }

    // MARK: - TransitingType

    @Test("TransitingType file case")
    func transitingTypeFile() {
        let type = TransitingType.file
        if case .file = type {
            // Success
        } else {
            Issue.record("Expected .file case")
        }
    }

    @Test("TransitingType coordinatedFile case")
    func transitingTypeCoordinatedFile() {
        let type = TransitingType.coordinatedFile
        if case .coordinatedFile = type {
            // Success
        } else {
            Issue.record("Expected .coordinatedFile case")
        }
    }

    @Test("TransitingType userDefaults case")
    func transitingTypeUserDefaults() {
        let type = TransitingType.userDefaults
        if case .userDefaults = type {
            // Success
        } else {
            Issue.record("Expected .userDefaults case")
        }
    }

    // MARK: - SerializationFormat

    @Test("SerializationFormat json case")
    func serializationFormatJSON() {
        let format = SerializationFormat.json
        if case .json = format {
            // Success
        } else {
            Issue.record("Expected .json case")
        }
    }

    // MARK: - Sendable Conformance

    @Test("Configuration is Sendable")
    func configurationSendable() async {
        let config = Configuration(appGroupIdentifier: "group.test")
        await Task {
            let _ = config.appGroupIdentifier
        }.value
    }

    @Test("TransitingType is Sendable")
    func transitingTypeSendable() async {
        let type = TransitingType.file
        await Task {
            let _ = type
        }.value
    }

    // MARK: - Builder Pattern (if applicable)

    @Test("Configuration with different transiting strategies")
    func differentTransitingStrategies() {
        let fileConfig = Configuration(appGroupIdentifier: "group.test", transitingStrategy: .file)
        let coordConfig = Configuration(appGroupIdentifier: "group.test", transitingStrategy: .coordinatedFile)
        let defaultsConfig = Configuration(appGroupIdentifier: "group.test", transitingStrategy: .userDefaults)

        #expect(fileConfig.transitingStrategy == .file)
        #expect(coordConfig.transitingStrategy == .coordinatedFile)
        #expect(defaultsConfig.transitingStrategy == .userDefaults)
    }
}
