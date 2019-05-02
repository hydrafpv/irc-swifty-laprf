# ImmersionRC LapRF SDK for Swift
![iOS](https://img.shields.io/badge/iOS-10.2%2B-blue.svg)
![macOS](https://img.shields.io/badge/macOS-10.13%2B-blue.svg)
![Swift 4.2](https://img.shields.io/badge/swift-4.2-orange.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![CocoaPods](https://cocoapod-badges.herokuapp.com/v/IRCSwiftyLapRF/badge.svg)](https://cocoapods.org/pods/IRCSwiftyLapRF)

Serialization Library to encode and decode binary messages from ImmersionRC FPV Timers.
Compatible with Bluetooth and USB connection types:
- IRCSwiftyLapRF/SwiftySensors for BLE Connections
- IRCSwiftyLapRF/SerialUSB for BLE Connections
- Ethernet is not supported yet

IRCLapRFDevice is the main class that ingests binary data delivered over BLE or USB and maintains its own state. It also notifies a delegate of data changes.

To send messages to the the device, you use the static functions on IRCLapRFProtocol to create byte arrays that you send over BLE or USB. The IRCLapRFService and IRCLapRFUSBConnection classes provide helper functions.

Demos for using SwiftySensors and ORSSerialPort are needed.

If you are having problems reading data from the device over USB, make sure to send it the "Enable Binary Protocol" message first.

BUGS:
- Sending messages too fast can result in some of them being ignored. Need to develop a queueing system to rate-limit the writes.
- Setting the RTC (Real Time Clock) currently shuts the device down. Something is wrong with the message.
- There are a few unknown fields in the Passing Records (transponder ID and ???).

ToDos:
- Limit the status update interval to prevent "lock out".
- Document the Gain and Treshold values (reference the LapRF manual)
- Improve the delegate protocol to give more granular data on what has changed
- Figure out how to request the "settings" fields from the device
- Fix up the BLE Service (not tested very much yet)
- Add a Band + Channel mapping for frequencies
- Test BLE on tvOS (shouldn't be an issue)



https://docs.google.com/document/d/14s5UGETJ-V6FeKhqPQLM142oCMjaFw0qwsx6tuxQxq8/edit#