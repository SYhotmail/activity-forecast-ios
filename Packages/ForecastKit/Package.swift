// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ForecastKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // Domain, scoring and data only (constitution Principle V). View models live in the app.
        .library(name: "ForecastKit", targets: ["ForecastKit"])
    ],
    targets: [
        .target(name: "ForecastKit"),
        .testTarget(
            name: "ForecastKitTests",
            dependencies: ["ForecastKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
