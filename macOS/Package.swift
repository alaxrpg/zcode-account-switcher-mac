// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZCodeAccountSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ZCodeAccountSwitcher",
            targets: ["ZCodeAccountSwitcher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ZCodeAccountSwitcher",
            path: "Sources/ZCodeAccountSwitcher"
        )
    ]
)
