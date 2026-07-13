import Foundation

public enum RecordingElapsedTimeFormatter {
    public static func string(startedAt: Date, now: Date = Date()) -> String {
        string(elapsedSeconds: now.timeIntervalSince(startedAt))
    }

    public static func string(elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsedSeconds.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
