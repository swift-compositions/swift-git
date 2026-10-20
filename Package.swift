// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-git",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Git", targets: ["Git Foundation"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-git-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Git Foundation",
            dependencies: [
                .product(name: "Git Standard", package: "swift-git-standard"),
                .product(name: "Process", package: "swift-process"),
            ],
            path: "Sources/Git"
        ),
        .testTarget(
            name: "Git Tests",
            dependencies: ["Git Foundation"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableExperimentalFeature("Lifetimes"),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        ]
}
