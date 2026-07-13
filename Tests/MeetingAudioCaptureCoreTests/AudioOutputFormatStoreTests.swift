import Foundation
import Testing
@testable import MeetingAudioCaptureCore

@Suite
struct AudioOutputFormatStoreTests {
    @Test
    func loadsM4AWhenNoFormatIsSaved() {
        let defaults = makeUserDefaults()
        let store = AudioOutputFormatStore(userDefaults: defaults)

        let outputFormat = store.loadOutputFormat()

        #expect(outputFormat == .m4a)
    }

    @Test
    func savesAndLoadsSelectedFormat() {
        let defaults = makeUserDefaults()
        let store = AudioOutputFormatStore(userDefaults: defaults)

        store.saveOutputFormat(.wav)
        let outputFormat = store.loadOutputFormat()

        #expect(outputFormat == .wav)
    }

    @Test
    func fallsBackToM4AForUnknownStoredFormat() {
        let defaults = makeUserDefaults()
        defaults.set("flac", forKey: AudioOutputFormatStore.defaultKey)
        let store = AudioOutputFormatStore(userDefaults: defaults)

        let outputFormat = store.loadOutputFormat()

        #expect(outputFormat == .m4a)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "MeetingAudioCaptureTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
