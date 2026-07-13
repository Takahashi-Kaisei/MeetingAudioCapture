import Foundation

public struct AudioOutputFormatStore {
    public static let defaultKey = "audioOutputFormat"

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadOutputFormat() -> AudioOutputFormat {
        guard let rawValue = userDefaults.string(forKey: key),
              let outputFormat = AudioOutputFormat(rawValue: rawValue) else {
            return .m4a
        }
        return outputFormat
    }

    public func saveOutputFormat(_ outputFormat: AudioOutputFormat) {
        userDefaults.set(outputFormat.rawValue, forKey: key)
    }
}
