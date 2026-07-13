import Foundation

public enum OutputDirectoryFallbackReason: Equatable, Sendable {
    case missingOrNotDirectory
    case notWritable
}

public struct OutputDirectoryResolution: Equatable, Sendable {
    public let outputDirectory: URL
    public let attemptedDirectory: URL?
    public let fallbackReason: OutputDirectoryFallbackReason?

    public var didFallback: Bool {
        fallbackReason != nil
    }
}

public struct OutputDirectoryStore {
    public static let defaultKey = "outputDirectoryPath"

    private let userDefaults: UserDefaults
    private let key: String
    private let fileManager: FileManager

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = Self.defaultKey,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.fileManager = fileManager
    }

    public func loadOutputDirectory() -> OutputDirectoryResolution {
        guard let path = userDefaults.string(forKey: key), !path.isEmpty else {
            return OutputDirectoryResolution(
                outputDirectory: Self.downloadsDirectory,
                attemptedDirectory: nil,
                fallbackReason: nil
            )
        }

        let storedDirectory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        if !isExistingDirectory(storedDirectory) {
            return fallback(attemptedDirectory: storedDirectory, reason: .missingOrNotDirectory)
        }

        guard isWritableDirectory(storedDirectory) else {
            return fallback(attemptedDirectory: storedDirectory, reason: .notWritable)
        }

        return OutputDirectoryResolution(
            outputDirectory: storedDirectory,
            attemptedDirectory: storedDirectory,
            fallbackReason: nil
        )
    }

    public func saveOutputDirectory(_ directory: URL) {
        userDefaults.set(directory.standardizedFileURL.path, forKey: key)
    }

    public func clearOutputDirectory() {
        userDefaults.removeObject(forKey: key)
    }

    public func isUsableDirectory(_ directory: URL) -> Bool {
        isExistingDirectory(directory) && isWritableDirectory(directory)
    }

    public static var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
    }

    private func fallback(
        attemptedDirectory: URL,
        reason: OutputDirectoryFallbackReason
    ) -> OutputDirectoryResolution {
        OutputDirectoryResolution(
            outputDirectory: Self.downloadsDirectory,
            attemptedDirectory: attemptedDirectory,
            fallbackReason: reason
        )
    }

    private func isExistingDirectory(_ directory: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func isWritableDirectory(_ directory: URL) -> Bool {
        fileManager.isWritableFile(atPath: directory.path)
    }
}
