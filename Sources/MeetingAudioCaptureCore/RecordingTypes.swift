import Foundation

public enum RecordingMode: String, CaseIterable, Sendable {
    case onlineMeeting
    case inPerson

    public var displayName: String {
        switch self {
        case .onlineMeeting:
            return "オンライン会議"
        case .inPerson:
            return "対面"
        }
    }

    public var capturesSystemAudio: Bool {
        self == .onlineMeeting
    }

    public var filenameComponent: String {
        switch self {
        case .onlineMeeting:
            return "online-meeting"
        case .inPerson:
            return "in-person"
        }
    }
}

public enum AudioSourceKind: String, Sendable {
    case system
    case microphone
}

public struct RecordingSettings: Sendable {
    public var outputDirectory: URL
    public var sampleRate: Double
    public var channelCount: Int
    public var bitRate: Int
    public var segmentDurationSeconds: TimeInterval
    public var mixerLatencySeconds: TimeInterval
    public var sessionTitle: String?

    public init(
        outputDirectory: URL,
        sampleRate: Double = 48_000,
        channelCount: Int = 2,
        bitRate: Int = 192_000,
        segmentDurationSeconds: TimeInterval = 30 * 60,
        mixerLatencySeconds: TimeInterval = 0.35,
        sessionTitle: String? = nil
    ) {
        self.outputDirectory = outputDirectory
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitRate = bitRate
        self.segmentDurationSeconds = segmentDurationSeconds
        self.mixerLatencySeconds = mixerLatencySeconds
        self.sessionTitle = sessionTitle
    }

    public static var downloadsDefault: RecordingSettings {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        return RecordingSettings(outputDirectory: downloads)
    }
}

public struct MicrophoneDevice: Identifiable, Equatable, Sendable {
    public let id: String?
    public let name: String

    public init(id: String?, name: String) {
        self.id = id
        self.name = name
    }

    public static let systemDefault = MicrophoneDevice(id: nil, name: "システム標準")
}

public enum RecorderState: Equatable, Sendable {
    case idle
    case recording(mode: RecordingMode, startedAt: Date)
    case stopping
    case failed(message: String)
}

public enum RecorderError: LocalizedError, Equatable {
    case noDisplayAvailable
    case noMicrophoneAvailable
    case permissionDenied(String)
    case unsupportedAudioFormat(String)
    case writerNotStarted
    case invalidBuffer(String)

    public var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            return "録音対象にできるディスプレイが見つかりません。"
        case .noMicrophoneAvailable:
            return "利用できるマイクが見つかりません。"
        case .permissionDenied(let message):
            return message
        case .unsupportedAudioFormat(let message):
            return message
        case .writerNotStarted:
            return "音声ファイルの書き込みを開始できていません。"
        case .invalidBuffer(let message):
            return message
        }
    }
}
