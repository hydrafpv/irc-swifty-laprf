// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IRCSwiftyLapRF",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v10)
    ],
    products: [
        .library(name: "IRCSwiftyLapRFCore", targets: ["IRCSwiftyLapRFCore"]),
        .library(name: "IRCSwiftyLapRFBluetooth", targets: ["IRCSwiftyLapRFBluetooth"]),
        .library(name: "IRCSwiftyLapRFEthernet", targets: ["IRCSwiftyLapRFEthernet"]),
        .library(name: "IRCSwiftyLapRFSerialUSB", targets: ["IRCSwiftyLapRFSerialUSB"])
    ],
    dependencies: [
        .package(url: "https://github.com/artman/Signals", from: Version(6, 1, 0)),
        .package(url: "https://github.com/kinetic-fit/sensors-swift", .branch("master")),
        .package(url: "https://github.com/netizen01/CocoaAsyncSocket", .branch("master")),
        .package(url: "https://github.com/armadsen/ORSSerialPort", .branch("master")),
    ],
    targets: [
        .target(name: "IRCSwiftyLapRFCore", dependencies: ["Signals"]),
        .target(name: "IRCSwiftyLapRFBluetooth", dependencies: ["IRCSwiftyLapRFCore", "SwiftySensors"]),
        .target(name: "IRCSwiftyLapRFEthernet", dependencies: ["IRCSwiftyLapRFCore", "CocoaAsyncSocket"]),
        .target(name: "IRCSwiftyLapRFSerialUSB", dependencies: ["IRCSwiftyLapRFCore", "ORSSerial"])
    ]
)
