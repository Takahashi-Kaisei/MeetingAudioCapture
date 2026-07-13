import Foundation

public final class TimelineAudioMixer {
    public let outputSampleRate: Double
    public let latencyFrames: Int64
    public let maxSilentGapFrames: Int64

    private var baseTimeSeconds: Double?
    private var cursorFrame: Int64 = 0
    private var pendingInterleavedSamples: [Float] = []

    public init(
        outputSampleRate: Double = 48_000,
        latencySeconds: TimeInterval = 0.35,
        maxSilentGapSeconds: TimeInterval = 5
    ) {
        self.outputSampleRate = outputSampleRate
        self.latencyFrames = max(0, Int64((latencySeconds * outputSampleRate).rounded()))
        self.maxSilentGapFrames = max(0, Int64((maxSilentGapSeconds * outputSampleRate).rounded()))
    }

    public func append(_ chunk: AudioChunk) -> [StereoPCMBuffer] {
        if baseTimeSeconds == nil {
            baseTimeSeconds = chunk.startTimeSeconds
        }

        let baseTime = baseTimeSeconds ?? chunk.startTimeSeconds
        let startFrame = max(0, Int64(((chunk.startTimeSeconds - baseTime) * outputSampleRate).rounded()))
        let stereo = chunk.resampledStereo(targetSampleRate: outputSampleRate)
        let endFrame = startFrame + Int64(stereo.frameCount)

        if pendingInterleavedSamples.isEmpty, startFrame > cursorFrame + maxSilentGapFrames {
            cursorFrame = startFrame
        }

        mix(stereo, at: startFrame)
        return drain(upToFrame: max(cursorFrame, endFrame - latencyFrames))
    }

    public func finish() -> [StereoPCMBuffer] {
        drain(upToFrame: cursorFrame + Int64(pendingInterleavedSamples.count / 2), force: true)
    }

    private func mix(_ buffer: StereoPCMBuffer, at startFrame: Int64) {
        guard buffer.frameCount > 0 else {
            return
        }

        let writableStartFrame = max(startFrame, cursorFrame)
        let skippedFrames = Int(max(0, writableStartFrame - startFrame))
        guard skippedFrames < buffer.frameCount else {
            return
        }

        let writableFrames = buffer.frameCount - skippedFrames
        ensurePendingFrames(upTo: writableStartFrame + Int64(writableFrames))
        let pendingStartSample = Int(writableStartFrame - cursorFrame) * 2
        let sourceStartSample = skippedFrames * 2

        for sampleOffset in 0..<(writableFrames * 2) {
            let pendingIndex = pendingStartSample + sampleOffset
            let mixed = pendingInterleavedSamples[pendingIndex] + buffer.interleavedSamples[sourceStartSample + sampleOffset]
            pendingInterleavedSamples[pendingIndex] = max(-1, min(1, mixed))
        }
    }

    private func ensurePendingFrames(upTo absoluteEndFrame: Int64) {
        let requiredFrames = max(0, absoluteEndFrame - cursorFrame)
        let requiredSamples = Int(requiredFrames) * 2
        if pendingInterleavedSamples.count < requiredSamples {
            pendingInterleavedSamples.append(contentsOf: repeatElement(0, count: requiredSamples - pendingInterleavedSamples.count))
        }
    }

    private func drain(upToFrame requestedEndFrame: Int64, force: Bool = false) -> [StereoPCMBuffer] {
        let availableFrames = Int64(pendingInterleavedSamples.count / 2)
        let safeEndFrame = min(max(cursorFrame, requestedEndFrame), cursorFrame + availableFrames)
        let framesToDrain = Int(safeEndFrame - cursorFrame)

        guard framesToDrain > 0 else {
            return []
        }

        if !force, framesToDrain < 256 {
            return []
        }

        let sampleCount = framesToDrain * 2
        let samples = Array(pendingInterleavedSamples.prefix(sampleCount))
        pendingInterleavedSamples.removeFirst(sampleCount)
        cursorFrame += Int64(framesToDrain)

        return [StereoPCMBuffer(sampleRate: outputSampleRate, interleavedSamples: samples)]
    }
}
