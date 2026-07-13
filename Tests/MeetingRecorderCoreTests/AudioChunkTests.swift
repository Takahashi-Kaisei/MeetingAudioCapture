import Testing
@testable import MeetingRecorderCore

@Suite
struct AudioChunkTests {
    @Test
    func systemStereoKeepsLeftAndRightChannels() throws {
        let chunk = try AudioChunk(
            source: .system,
            startTimeSeconds: 0,
            sampleRate: 48_000,
            channels: [
                [0.1, 0.2, 0.3],
                [0.4, 0.5, 0.6]
            ]
        )

        let stereo = chunk.resampledStereo(targetSampleRate: 48_000)

        expectSamples(stereo.interleavedSamples, [0.1, 0.4, 0.2, 0.5, 0.3, 0.6])
    }

    @Test
    func microphoneIsCenteredFromAllInputChannels() throws {
        let chunk = try AudioChunk(
            source: .microphone,
            startTimeSeconds: 0,
            sampleRate: 48_000,
            channels: [
                [1.0, -1.0],
                [0.0, 0.5]
            ]
        )

        let stereo = chunk.resampledStereo(targetSampleRate: 48_000)

        expectSamples(stereo.interleavedSamples, [0.5, 0.5, -0.25, -0.25])
    }

    @Test
    func resamplingChangesFrameCount() throws {
        let chunk = try AudioChunk(
            source: .system,
            startTimeSeconds: 0,
            sampleRate: 24_000,
            channels: [[0.0, 1.0]]
        )

        let stereo = chunk.resampledStereo(targetSampleRate: 48_000)

        #expect(stereo.frameCount == 4)
        #expect(abs(stereo.interleavedSamples[0] - 0.0) < 0.0001)
        #expect(abs(stereo.interleavedSamples[1] - 0.0) < 0.0001)
    }
}
