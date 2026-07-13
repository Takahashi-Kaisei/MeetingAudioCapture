import AVFoundation
import CoreGraphics
import Foundation

public enum PermissionStatus: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted
    case unknown
}

public enum PermissionService {
    public static func microphoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    public static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public static func screenCaptureStatus() -> PermissionStatus {
        CGPreflightScreenCaptureAccess() ? .authorized : .notDetermined
    }

    @discardableResult
    public static func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
