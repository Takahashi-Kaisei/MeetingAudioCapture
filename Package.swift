// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MeetingAudioCapture",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "MeetingAudioCaptureCore",
            targets: ["MeetingAudioCaptureCore"]
        ),
        .executable(
            name: "MeetingAudioCapture",
            targets: ["MeetingAudioCaptureApp"]
        )
    ],
    targets: [
        .target(
            name: "MeetingAudioCaptureCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVFAudio"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .executableTarget(
            name: "MeetingAudioCaptureApp",
            dependencies: ["MeetingAudioCaptureCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "MeetingAudioCaptureCoreTests",
            dependencies: ["MeetingAudioCaptureCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ]),
                .linkedFramework("Testing")
            ]
        )
    ]
)
