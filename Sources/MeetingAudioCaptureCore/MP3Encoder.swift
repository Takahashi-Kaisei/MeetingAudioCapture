import Foundation

protocol MP3Encoding {
    func encodeM4A(sourceURL: URL, destinationURL: URL) throws
}

struct ExternalMP3Encoder: MP3Encoding {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func encodeM4A(sourceURL: URL, destinationURL: URL) throws {
        guard let ffmpegURL = findFFmpeg() else {
            throw RecorderError.mp3EncoderUnavailable
        }

        try? fileManager.removeItem(at: destinationURL)
        try run(
            ffmpegURL,
            arguments: [
                "-y",
                "-hide_banner",
                "-loglevel", "error",
                "-i", sourceURL.path,
                "-ar", "44100",
                "-ab", "128k",
                destinationURL.path
            ]
        )
    }

    private func findFFmpeg() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in candidates {
            if fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func run(_ executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
        } catch {
            throw RecorderError.mp3EncodingFailed(error.recorderDiagnosticMessage)
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let diagnostic = message?.isEmpty == false
                ? message!
                : "ffmpegがステータス \(process.terminationStatus) で終了しました。"
            throw RecorderError.mp3EncodingFailed(diagnostic)
        }
    }
}
