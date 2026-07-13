import Foundation
import Testing
@testable import MeetingAudioCaptureCore

@Suite
struct SegmentedAudioFileWriterTests {
    @Test
    func writerSplitsLongBuffersIntoMultipleM4AFiles() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MeetingAudioCaptureTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let settings = RecordingSettings(
            outputDirectory: directory,
            sampleRate: 48_000,
            bitRate: 192_000,
            segmentDurationSeconds: 4_096 / 48_000
        )
        let writer = SegmentedAudioFileWriter(
            settings: settings,
            mode: .onlineMeeting,
            startedAt: Date(timeIntervalSince1970: 0)
        )

        var samples: [Float] = []
        for frame in 0..<10_000 {
            let value = Float(sin(Double(frame) / 40))
            samples.append(value)
            samples.append(value)
        }

        try writer.write(StereoPCMBuffer(sampleRate: 48_000, interleavedSamples: samples))
        writer.close()

        #expect(writer.completedFileURLs.count == 3)
        for fileURL in writer.completedFileURLs {
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
}
