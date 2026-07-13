import AVFAudio
import AudioToolbox
import Foundation

extension StereoPCMBuffer {
    func makeAVAudioPCMBuffer() throws -> AVAudioPCMBuffer {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        ) else {
            throw RecorderError.invalidBuffer("AVAudioFormatを作成できませんでした。")
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw RecorderError.invalidBuffer("AVAudioPCMBufferを作成できませんでした。")
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else {
            throw RecorderError.invalidBuffer("PCMバッファのチャンネルデータにアクセスできません。")
        }

        for frame in 0..<frameCount {
            channelData[0][frame] = interleavedSamples[frame * 2]
            channelData[1][frame] = interleavedSamples[frame * 2 + 1]
        }

        return buffer
    }
}

public final class SegmentedAudioFileWriter {
    public private(set) var completedFileURLs: [URL] = []

    private let outputDirectory: URL
    private let sampleRate: Double
    private let bitRate: Int
    private let segmentFrameLimit: Int64
    private let fileManager: FileManager
    private let filenameGenerator: RecordingFilenameGenerator

    private var currentFile: AVAudioFile?
    private var currentFileURL: URL?
    private var currentSegmentFrames: Int64 = 0
    private var segmentIndex = 1

    public init(
        settings: RecordingSettings,
        mode: RecordingMode,
        startedAt: Date = Date(),
        fileManager: FileManager = .default
    ) {
        self.outputDirectory = settings.outputDirectory
        self.sampleRate = settings.sampleRate
        self.bitRate = settings.bitRate
        self.segmentFrameLimit = max(1, Int64((settings.segmentDurationSeconds * settings.sampleRate).rounded()))
        self.fileManager = fileManager

        self.filenameGenerator = RecordingFilenameGenerator(
            startedAt: startedAt,
            mode: mode,
            sessionTitle: settings.sessionTitle
        )
    }

    public func write(_ buffer: StereoPCMBuffer) throws {
        guard buffer.sampleRate == sampleRate else {
            throw RecorderError.invalidBuffer("書き込み対象のサンプルレートが録音設定と一致していません。")
        }

        var offsetFrame = 0
        while offsetFrame < buffer.frameCount {
            if currentFile == nil {
                try startNextSegment()
            }

            let remainingFramesInSegment = Int(max(1, segmentFrameLimit - currentSegmentFrames))
            let framesToWrite = min(remainingFramesInSegment, buffer.frameCount - offsetFrame)
            let slice = buffer.slice(startFrame: offsetFrame, frameCount: framesToWrite)
            let pcm = try slice.makeAVAudioPCMBuffer()
            try currentFile?.write(from: pcm)

            currentSegmentFrames += Int64(framesToWrite)
            offsetFrame += framesToWrite

            if currentSegmentFrames >= segmentFrameLimit {
                closeCurrentSegment()
            }
        }
    }

    public func close() {
        closeCurrentSegment()
    }

    private func startNextSegment() throws {
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let fileName = filenameGenerator.fileName(segmentIndex: segmentIndex)
        let fileURL = outputDirectory.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: bitRate
        ]

        currentFile = try AVAudioFile(
            forWriting: fileURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        currentFileURL = fileURL
        currentSegmentFrames = 0
        segmentIndex += 1
    }

    private func closeCurrentSegment() {
        guard currentFile != nil else {
            return
        }

        currentFile?.close()
        if let currentFileURL {
            completedFileURLs.append(currentFileURL)
        }

        currentFile = nil
        currentFileURL = nil
        currentSegmentFrames = 0
    }
}
