import Foundation

public struct SegmentMergePreferenceStore {
    public static let defaultKey = "mergeSegmentsAfterRecording"

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadMergeSegmentsAfterRecording() -> Bool {
        userDefaults.bool(forKey: key)
    }

    public func saveMergeSegmentsAfterRecording(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: key)
    }
}
