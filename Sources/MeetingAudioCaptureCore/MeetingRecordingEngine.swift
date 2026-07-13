@preconcurrency import AVFoundation
@preconcurrency import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

@available(macOS 15.0, *)
public final class MeetingRecordingEngine: NSObject {
    public var onStateChange: ((RecorderState) -> Void)?
    public var onError: ((Error) -> Void)?
    public var onFinished: (([URL]) -> Void)?

    private let captureQueue = DispatchQueue(label: "app.meeting-audio-capture.capture")
    private let converter = SampleBufferAudioConverter()

    private var state: RecorderState = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    private var settings: RecordingSettings
    private var mixer: TimelineAudioMixer?
    private var writer: SegmentedAudioFileWriter?
    private var stream: SCStream?
    private var captureSession: AVCaptureSession?
    private var activeMode: RecordingMode?

    public init(settings: RecordingSettings = .downloadsDefault) {
        self.settings = settings
        super.init()
    }

    public func start(
        mode: RecordingMode,
        microphoneDeviceID: String?,
        sessionTitle: String? = nil,
        recordingSettings: RecordingSettings? = nil
    ) async throws {
        guard case .idle = state else {
            return
        }

        let startedAt = Date()
        let activeSettings = recordingSettings ?? settings
        settings = activeSettings

        var writerSettings = activeSettings
        writerSettings.sessionTitle = sessionTitle
        let writer = SegmentedAudioFileWriter(settings: writerSettings, mode: mode, startedAt: startedAt)
        let mixer = TimelineAudioMixer(
            outputSampleRate: activeSettings.sampleRate,
            latencySeconds: activeSettings.mixerLatencySeconds
        )

        await captureQueueAsync {
            self.writer = writer
            self.mixer = mixer
            self.activeMode = mode
        }

        do {
            switch mode {
            case .onlineMeeting:
                try await startScreenCapture(microphoneDeviceID: microphoneDeviceID)
            case .inPerson:
                try await startMicrophoneOnlyCapture(microphoneDeviceID: microphoneDeviceID)
            }
            state = .recording(mode: mode, startedAt: startedAt)
        } catch {
            await cleanupAfterFailedStart()
            state = .failed(message: error.localizedDescription)
            throw error
        }
    }

    public func stop() async {
        guard state != .idle else {
            return
        }

        state = .stopping

        if let stream {
            await stopScreenCapture(stream)
        }

        await stopMicrophoneOnlyCapture()

        let completedFiles = await captureQueueAsync {
            if let outputs = self.mixer?.finish() {
                for output in outputs {
                    do {
                        try self.writer?.write(output)
                    } catch {
                        self.onError?(error)
                    }
                }
            }
            self.writer?.close()
            let urls = self.writer?.completedFileURLs ?? []
            self.writer = nil
            self.mixer = nil
            self.stream = nil
            self.captureSession = nil
            self.activeMode = nil
            return urls
        }

        state = .idle
        onFinished?(completedFiles)
    }

    private func startScreenCapture(microphoneDeviceID: String?) async throws {
        let content = try await shareableContent()
        guard let display = content.displays.first else {
            throw RecorderError.noDisplayAvailable
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.capturesAudio = true
        configuration.captureMicrophone = true
        configuration.sampleRate = Int(settings.sampleRate)
        configuration.channelCount = Int(settings.channelCount)
        configuration.excludesCurrentProcessAudio = true
        if let microphoneDeviceID {
            configuration.microphoneCaptureDeviceID = microphoneDeviceID
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: captureQueue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: captureQueue)

        self.stream = stream
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func startMicrophoneOnlyCapture(microphoneDeviceID: String?) async throws {
        try await captureQueueThrowing {
            guard let device = MicrophoneDeviceProvider.captureDevice(for: microphoneDeviceID) else {
                throw RecorderError.noMicrophoneAvailable
            }

            let session = AVCaptureSession()
            session.beginConfiguration()

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw RecorderError.noMicrophoneAvailable
            }
            session.addInput(input)

            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: self.captureQueue)
            guard session.canAddOutput(output) else {
                throw RecorderError.noMicrophoneAvailable
            }
            session.addOutput(output)

            session.commitConfiguration()
            self.captureSession = session
            session.startRunning()
        }
    }

    private func stopScreenCapture(_ stream: SCStream) async {
        await withCheckedContinuation { continuation in
            stream.stopCapture { _ in
                continuation.resume()
            }
        }
    }

    private func stopMicrophoneOnlyCapture() async {
        await captureQueueAsync {
            self.captureSession?.stopRunning()
        }
    }

    private func cleanupAfterFailedStart() async {
        await captureQueueAsync {
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.stream = nil
            self.writer?.close()
            self.writer = nil
            self.mixer = nil
            self.activeMode = nil
        }
    }

    private func shareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let content else {
                    continuation.resume(throwing: RecorderError.noDisplayAvailable)
                    return
                }
                continuation.resume(returning: content)
            }
        }
    }

    private func process(sampleBuffer: CMSampleBuffer, source: AudioSourceKind) {
        do {
            let chunk = try converter.chunk(from: sampleBuffer, source: source)
            let outputs = mixer?.append(chunk) ?? []
            for output in outputs {
                try writer?.write(output)
            }
        } catch {
            onError?(error)
        }
    }

    private func captureQueueAsync<T>(_ operation: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            captureQueue.async {
                continuation.resume(returning: operation())
            }
        }
    }

    private func captureQueueThrowing<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@available(macOS 15.0, *)
extension MeetingRecordingEngine: SCStreamOutput, SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .audio:
            process(sampleBuffer: sampleBuffer, source: .system)
        case .microphone:
            process(sampleBuffer: sampleBuffer, source: .microphone)
        default:
            break
        }
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError?(error)
    }
}

@available(macOS 15.0, *)
extension MeetingRecordingEngine: AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        process(sampleBuffer: sampleBuffer, source: .microphone)
    }
}
