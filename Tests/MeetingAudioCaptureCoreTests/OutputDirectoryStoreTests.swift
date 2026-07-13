import Foundation
import Testing
@testable import MeetingAudioCaptureCore

@Suite
struct OutputDirectoryStoreTests {
    @Test
    func loadsDownloadsWhenNoDirectoryIsSaved() {
        let defaults = makeUserDefaults()
        let store = OutputDirectoryStore(userDefaults: defaults)

        let resolution = store.loadOutputDirectory()

        #expect(resolution.outputDirectory == OutputDirectoryStore.downloadsDirectory)
        #expect(resolution.didFallback == false)
    }

    @Test
    func savesAndLoadsExistingDirectory() throws {
        let defaults = makeUserDefaults()
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OutputDirectoryStore(userDefaults: defaults)

        store.saveOutputDirectory(directory)
        let resolution = store.loadOutputDirectory()

        #expect(resolution.outputDirectory == directory.standardizedFileURL)
        #expect(resolution.didFallback == false)
    }

    @Test
    func fallsBackToDownloadsWhenStoredDirectoryDoesNotExist() {
        let defaults = makeUserDefaults()
        let missingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)
        let store = OutputDirectoryStore(userDefaults: defaults)

        store.saveOutputDirectory(missingDirectory)
        let resolution = store.loadOutputDirectory()

        #expect(resolution.outputDirectory == OutputDirectoryStore.downloadsDirectory)
        #expect(resolution.attemptedDirectory == missingDirectory.standardizedFileURL)
        #expect(resolution.fallbackReason == .missingOrNotDirectory)
    }

    @Test
    func clearsSavedDirectory() throws {
        let defaults = makeUserDefaults()
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OutputDirectoryStore(userDefaults: defaults)

        store.saveOutputDirectory(directory)
        store.clearOutputDirectory()
        let resolution = store.loadOutputDirectory()

        #expect(resolution.outputDirectory == OutputDirectoryStore.downloadsDirectory)
        #expect(resolution.didFallback == false)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "MeetingAudioCaptureTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MeetingAudioCaptureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.standardizedFileURL
    }
}
