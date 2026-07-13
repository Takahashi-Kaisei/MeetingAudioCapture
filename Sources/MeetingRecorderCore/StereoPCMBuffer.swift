import Foundation

public struct StereoPCMBuffer: Equatable, Sendable {
    public let sampleRate: Double
    public private(set) var interleavedSamples: [Float]

    public var frameCount: Int {
        interleavedSamples.count / 2
    }

    public init(sampleRate: Double, interleavedSamples: [Float]) {
        precondition(interleavedSamples.count.isMultiple(of: 2), "Stereo samples must be interleaved L/R pairs.")
        self.sampleRate = sampleRate
        self.interleavedSamples = interleavedSamples
    }

    public init(sampleRate: Double, silentFrames: Int) {
        self.sampleRate = sampleRate
        self.interleavedSamples = Array(repeating: 0, count: max(0, silentFrames) * 2)
    }

    public func slice(startFrame: Int, frameCount requestedFrames: Int) -> StereoPCMBuffer {
        let safeStart = min(max(0, startFrame), frameCount)
        let safeEnd = min(frameCount, safeStart + max(0, requestedFrames))
        let sampleStart = safeStart * 2
        let sampleEnd = safeEnd * 2
        return StereoPCMBuffer(
            sampleRate: sampleRate,
            interleavedSamples: Array(interleavedSamples[sampleStart..<sampleEnd])
        )
    }
}
