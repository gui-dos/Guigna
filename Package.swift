// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Guigna",
    products: [
        .library(
            name: "Guigna",
            targets: ["Guigna"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Guigna",
            dependencies: [],
            path: "Sources"),
	     .testTarget(
	            name: "GuignaTests",
	            dependencies: ["Guigna"])
    ]
)
