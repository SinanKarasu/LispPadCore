// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LispPadCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "LispPadCore",
            targets: ["LispPadCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SinanKarasu/swift-lispkit.git", revision: "326a7f813f7d5ab30186a1b03d65c6690ecfe910")
    ],
    targets: [
        .target(
            name: "LispPadCore",
            dependencies: [
                .product(name: "LispKit", package: "swift-lispkit")
            ],
            resources: [
                .process("Resources/Root/Prelude.scm")
            ]
        )
    ]
)
