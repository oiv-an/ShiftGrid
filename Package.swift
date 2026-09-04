// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ShiftGrid",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ShiftGrid", targets: ["ShiftGrid"])
    ],
    targets: [
        .executableTarget(
            name: "ShiftGrid",
            path: "AppSources/ShiftGrid"
        ),
        .testTarget(
            name: "ShiftGridTests",
            dependencies: ["ShiftGrid"]
        )
    ]
)
