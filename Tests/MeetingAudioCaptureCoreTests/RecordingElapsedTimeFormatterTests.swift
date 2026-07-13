import Foundation
import Testing
@testable import MeetingAudioCaptureCore

@Suite
struct RecordingElapsedTimeFormatterTests {
    @Test
    func formatsElapsedSecondsAsHoursMinutesAndSeconds() {
        let formatted = RecordingElapsedTimeFormatter.string(elapsedSeconds: 3_723)

        #expect(formatted == "01:02:03")
    }

    @Test
    func floorsFractionalSeconds() {
        let formatted = RecordingElapsedTimeFormatter.string(elapsedSeconds: 65.9)

        #expect(formatted == "00:01:05")
    }

    @Test
    func clampsNegativeElapsedTimeToZero() {
        let formatted = RecordingElapsedTimeFormatter.string(elapsedSeconds: -1)

        #expect(formatted == "00:00:00")
    }

    @Test
    func formatsElapsedTimeFromStartAndNowDates() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 100 + 25 * 3_600 + 4)

        let formatted = RecordingElapsedTimeFormatter.string(startedAt: startedAt, now: now)

        #expect(formatted == "25:00:04")
    }
}
