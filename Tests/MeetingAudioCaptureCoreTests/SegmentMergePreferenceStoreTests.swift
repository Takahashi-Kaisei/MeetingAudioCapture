import Foundation
import Testing
@testable import MeetingAudioCaptureCore

@Suite
struct SegmentMergePreferenceStoreTests {
    @Test
    func loadsFalseWhenNoPreferenceIsSaved() {
        let defaults = makeUserDefaults()
        let store = SegmentMergePreferenceStore(userDefaults: defaults)

        let isEnabled = store.loadMergeSegmentsAfterRecording()

        #expect(isEnabled == false)
    }

    @Test
    func savesAndLoadsMergePreference() {
        let defaults = makeUserDefaults()
        let store = SegmentMergePreferenceStore(userDefaults: defaults)

        store.saveMergeSegmentsAfterRecording(true)
        let isEnabled = store.loadMergeSegmentsAfterRecording()

        #expect(isEnabled == true)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "MeetingAudioCaptureTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
