import AudioToolbox
import AVFAudio
import CoreMedia
import Foundation

public final class SampleBufferAudioConverter {
    public init() {}

    public func chunk(from sampleBuffer: CMSampleBuffer, source: AudioSourceKind) throws -> AudioChunk {
        guard CMSampleBufferIsValid(sampleBuffer) else {
            throw RecorderError.invalidBuffer("無効なCMSampleBufferです。")
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else {
            return try AudioChunk(source: source, startTimeSeconds: timestamp(sampleBuffer), sampleRate: 48_000, channels: [])
        }

        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            throw RecorderError.unsupportedAudioFormat("音声フォーマット情報を取得できませんでした。")
        }

        let asbd = streamDescription.pointee
        guard asbd.mFormatID == kAudioFormatLinearPCM else {
            throw RecorderError.unsupportedAudioFormat("Linear PCM以外の入力フォーマットには未対応です。")
        }

        let channels = Int(asbd.mChannelsPerFrame)
        guard channels > 0 else {
            throw RecorderError.unsupportedAudioFormat("入力チャンネル数が0です。")
        }

        let audioBufferListPointer = try retainedAudioBufferList(from: sampleBuffer)
        defer {
            audioBufferListPointer.raw.deallocate()
        }

        let decoded = try decode(
            audioBufferList: UnsafeMutableAudioBufferListPointer(audioBufferListPointer.list),
            asbd: asbd,
            channels: channels,
            frameCount: frameCount
        )

        return try AudioChunk(
            source: source,
            startTimeSeconds: timestamp(sampleBuffer),
            sampleRate: asbd.mSampleRate,
            channels: decoded
        )
    }

    private func timestamp(_ sampleBuffer: CMSampleBuffer) -> Double {
        let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        if seconds.isFinite {
            return seconds
        }
        return ProcessInfo.processInfo.systemUptime
    }

    private typealias RetainedAudioBufferList = (raw: UnsafeMutableRawPointer, list: UnsafeMutablePointer<AudioBufferList>)

    private func retainedAudioBufferList(from sampleBuffer: CMSampleBuffer) throws -> RetainedAudioBufferList {
        var sizeNeeded = 0
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &sizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: nil
        )

        guard status == noErr, sizeNeeded > 0 else {
            throw RecorderError.invalidBuffer("AudioBufferListのサイズ取得に失敗しました: \(status)")
        }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: sizeNeeded,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        var blockBuffer: CMBlockBuffer?

        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: list,
            bufferListSize: sizeNeeded,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            raw.deallocate()
            throw RecorderError.invalidBuffer("AudioBufferListの取得に失敗しました: \(status)")
        }

        return (raw, list)
    }

    private func decode(
        audioBufferList: UnsafeMutableAudioBufferListPointer,
        asbd: AudioStreamBasicDescription,
        channels: Int,
        frameCount: Int
    ) throws -> [[Float]] {
        let flags = asbd.mFormatFlags
        let isFloat = flags & kAudioFormatFlagIsFloat != 0
        let isSignedInteger = flags & kAudioFormatFlagIsSignedInteger != 0
        let isNonInterleaved = flags & kAudioFormatFlagIsNonInterleaved != 0
        let bitsPerChannel = Int(asbd.mBitsPerChannel)

        guard isFloat || isSignedInteger else {
            throw RecorderError.unsupportedAudioFormat("FloatまたはSigned Integer PCM以外の入力には未対応です。")
        }

        var decoded = Array(
            repeating: Array(repeating: Float(0), count: frameCount),
            count: channels
        )

        if isNonInterleaved {
            for channel in 0..<channels {
                guard channel < audioBufferList.count,
                      let data = audioBufferList[channel].mData else {
                    continue
                }

                for frame in 0..<frameCount {
                    decoded[channel][frame] = try sample(
                        data: data,
                        index: frame,
                        bitsPerChannel: bitsPerChannel,
                        isFloat: isFloat
                    )
                }
            }
        } else {
            guard let data = audioBufferList.first?.mData else {
                throw RecorderError.invalidBuffer("インターリーブPCMのデータが空です。")
            }

            for frame in 0..<frameCount {
                for channel in 0..<channels {
                    decoded[channel][frame] = try sample(
                        data: data,
                        index: frame * channels + channel,
                        bitsPerChannel: bitsPerChannel,
                        isFloat: isFloat
                    )
                }
            }
        }

        return decoded
    }

    private func sample(
        data: UnsafeMutableRawPointer,
        index: Int,
        bitsPerChannel: Int,
        isFloat: Bool
    ) throws -> Float {
        if isFloat {
            switch bitsPerChannel {
            case 32:
                return data.assumingMemoryBound(to: Float.self)[index]
            case 64:
                return Float(data.assumingMemoryBound(to: Double.self)[index])
            default:
                throw RecorderError.unsupportedAudioFormat("未対応のFloat PCMビット深度です: \(bitsPerChannel)")
            }
        }

        switch bitsPerChannel {
        case 16:
            return Float(data.assumingMemoryBound(to: Int16.self)[index]) / Float(Int16.max)
        case 32:
            return Float(data.assumingMemoryBound(to: Int32.self)[index]) / Float(Int32.max)
        default:
            throw RecorderError.unsupportedAudioFormat("未対応のInteger PCMビット深度です: \(bitsPerChannel)")
        }
    }
}
