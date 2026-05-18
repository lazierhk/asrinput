// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ASRInput",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "LLMRuleCore",
            path: "Sources/LLMRuleCore"
        ),
        .target(
            name: "OverlayHUDCore",
            path: "Sources/OverlayHUDCore"
        ),
        .executableTarget(
            name: "ASRInput",
            dependencies: ["LLMRuleCore", "OverlayHUDCore"],
            path: "Sources/ASRInput",
            exclude: [
                "Resources/AppIconSource.png",
                "Resources/Info.plist"
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/ASRInput/Resources/Info.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "CoreBehaviorCheck",
            dependencies: ["LLMRuleCore", "OverlayHUDCore"],
            path: "Tests/CoreBehaviorCheck"
        )
    ]
)
