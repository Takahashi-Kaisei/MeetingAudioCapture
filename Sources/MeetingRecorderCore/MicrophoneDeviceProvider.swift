import AVFoundation
import Foundation

public enum MicrophoneDeviceProvider {
    public static func availableInputDevices() -> [MicrophoneDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )

        let discovered = discovery.devices.map {
            MicrophoneDevice(id: $0.uniqueID, name: $0.localizedName)
        }

        return [.systemDefault] + discovered
    }

    static func captureDevice(for uniqueID: String?) -> AVCaptureDevice? {
        if let uniqueID {
            return AVCaptureDevice(uniqueID: uniqueID)
        }
        return AVCaptureDevice.default(for: .audio)
    }
}
