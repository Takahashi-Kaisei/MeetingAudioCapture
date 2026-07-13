import Foundation

public struct AudioChunk: Equatable, Sendable {
    public let source: AudioSourceKind
    public let startTimeSeconds: Double
    public let sampleRate: Double
    public let channels: [[Float]]

    public var frameCount: Int {
        channels.first?.count ?? 0
    }

    public init(
        source: AudioSourceKind,
        startTimeSeconds: Double,
        sampleRate: Double,
        channels: [[Float]]
    ) throws {
        let expectedFrames = channels.first?.count ?? 0
        guard channels.allSatisfy({ $0.count == expectedFrames }) else {
            throw RecorderError.invalidBuffer("チャンネルごとのフレーム数が一致していません。")
        }
        guard sampleRate > 0 else {
            throw RecorderError.invalidBuffer("サンプルレートが不正です。")
        }
        self.source = source
        self.startTimeSeconds = startTimeSeconds
        self.sampleRate = sampleRate
        self.channels = channels
    }

    public func resampledStereo(targetSampleRate: Double) -> StereoPCMBuffer {
        guard frameCount > 0 else {
            return StereoPCMBuffer(sampleRate: targetSampleRate, interleavedSamples: [])
        }

        let outputFrameCount = max(1, Int((Double(frameCount) * targetSampleRate / sampleRate).rounded()))
        var interleaved = Array(repeating: Float(0), count: outputFrameCount * 2)

        for outputFrame in 0..<outputFrameCount {
            let sourcePosition = Double(outputFrame) * sampleRate / targetSampleRate
            let left = sample(channel: .left, at: sourcePosition)
            let right = sample(channel: .right, at: sourcePosition)
            interleaved[outputFrame * 2] = left
            interleaved[outputFrame * 2 + 1] = right
        }

        return StereoPCMBuffer(sampleRate: targetSampleRate, interleavedSamples: interleaved)
    }

    private enum StereoChannel {
        case left
        case right
    }

    private func sample(channel: StereoChannel, at sourcePosition: Double) -> Float {
        guard !channels.isEmpty else {
            return 0
        }

        if source == .microphone {
            let mono = channels.map { interpolated($0, at: sourcePosition) }.reduce(0, +) / Float(channels.count)
            return mono
        }

        switch channel {
        case .left:
            return interpolated(channels[0], at: sourcePosition)
        case .right:
            if channels.count > 1 {
                return interpolated(channels[1], at: sourcePosition)
            }
            return interpolated(channels[0], at: sourcePosition)
        }
    }

    private func interpolated(_ samples: [Float], at position: Double) -> Float {
        guard !samples.isEmpty else {
            return 0
        }

        let lower = min(max(0, Int(position.rounded(.down))), samples.count - 1)
        let upper = min(lower + 1, samples.count - 1)
        let fraction = Float(position - Double(lower))
        return samples[lower] + (samples[upper] - samples[lower]) * fraction
    }
}
