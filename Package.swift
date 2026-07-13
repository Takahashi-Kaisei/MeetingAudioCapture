// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MeetingRecorder",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "MeetingRecorderCore",
            targets: ["MeetingRecorderCore"]
        ),
        .executable(
            name: "MeetingRecorder",
            targets: ["MeetingRecorderApp"]
        )
    ],
    targets: [
        .target(
            name: "MeetingRecorderCore",
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
            name: "MeetingRecorderApp",
            dependencies: ["MeetingRecorderCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "MeetingRecorderCoreTests",
            dependencies: ["MeetingRecorderCore"],
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
