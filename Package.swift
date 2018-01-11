// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pupil",
    dependencies: [
	.package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "0.12.77"),
  	.package(url: "https://github.com/swift-aws/s3.git", .upToNextMajor(from: "1.0.0")),
  	.package(url: "https://github.com/krad/morsel.git", from: "0.3.1"),
  	.package(url: "https://github.com/krad/memento.git", from: "0.0.8")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "pupil",
            dependencies: ["pupilCore"]),
	.target(
	    name: "pupilCore",
	    dependencies: ["Socket", "SwiftAWSS3", "morsel", "memento"]),
	.testTarget(
            name: "pupilTests",
            dependencies: ["pupil"]),
    ]
)
