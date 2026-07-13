import Foundation
import Testing
@testable import MeetingAudioCaptureCore

@Suite
struct RecorderErrorTests {
    @Test
    func classifiedKeepsExistingRecorderError() {
        let error = RecorderError.noMicrophoneAvailable

        let classified = RecorderError.classified(error, fallback: RecorderError.fileWriteFailed)

        #expect(classified == .noMicrophoneAvailable)
    }

    @Test
    func classifiedWrapsUnknownErrorWithFallback() {
        let error = NSError(domain: "RecorderErrorTests", code: 42, userInfo: [NSLocalizedDescriptionKey: "disk full"])

        let classified = RecorderError.classified(error, fallback: RecorderError.fileWriteFailed)

        #expect(classified == .fileWriteFailed("disk full"))
    }

    @Test
    func displayMessageIncludesRecoverySuggestion() {
        let error = RecorderError.fileWriteFailed("disk full")

        #expect(error.alertTitle == "ファイル保存に失敗しました")
        #expect(error.displayMessage.contains("disk full"))
        #expect(error.displayMessage.contains("次の対応:"))
        #expect(error.displayMessage.contains("保存先"))
    }
}
