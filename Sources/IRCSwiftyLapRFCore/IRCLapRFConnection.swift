//
//  IRCLapRFConnection.swift
//

import Foundation
import Signals

public protocol IRCLapRFConnection: class {
    var name: String { get }
    var device: IRCLapRFDevice { get }
    var lastRSSI: [[Float]] { set get }
    
    var onRSSIRangeUpdated: Signal<(IRCLapRFConnection, UInt8)> { get }
    var onRFSetupRead: Signal<(IRCLapRFConnection, UInt8)> { get }
    var onTimeUpdated: Signal<IRCLapRFConnection> { get }
    var onSettingsUpdated: Signal<IRCLapRFConnection> { get }
    var onStatusUpdated: Signal<IRCLapRFConnection> { get }
    var onPassingRecordRead: Signal<(IRCLapRFConnection, IRCLapRFDevice.PassingRecord)> { get }
    
    @discardableResult func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) -> Bool
    @discardableResult func configurePilotSlots(slots: [IRCLapRFDevice.RFSetup]) -> Bool
    @discardableResult func requestDescriptor() -> Bool
    @discardableResult func requestRFSetup() -> Bool
    @discardableResult func requestRFSetupForSlot(_ slot: UInt8) -> Bool
    @discardableResult func requestRTCTime() -> Bool
    @discardableResult func requestSettings() -> Bool
    @discardableResult func setGateState(_ state: IRCLapRFDevice.GateState) -> Bool
    @discardableResult func setMinLapTime(_ milliseconds: UInt32) -> Bool
    @discardableResult func setRSSIPacketRate(_ milliseconds: UInt32) -> Bool
    @discardableResult func setStatusMessageInterval(_ milliseconds: UInt16) -> Bool
}

public extension IRCLapRFConnection {
    func rssiRangeUpdated(_ device: IRCLapRFDevice, slot: UInt8) {
        let rssi = device.rssiPerSlot[Int(slot)]
        lastRSSI[Int(slot)].append(rssi.lastRssi)
        while lastRSSI[Int(slot)].count > 120 {
            lastRSSI[Int(slot)].removeFirst()
        }
        onRSSIRangeUpdated => (self, slot)
    }
    
    func rfSetupRead(_ device: IRCLapRFDevice, slot: UInt8) {
        onRFSetupRead => (self, slot)
    }
    
    func timeUpdated(_ device: IRCLapRFDevice) {
        onTimeUpdated => self
    }
    
    func settingsUpdated(_ device: IRCLapRFDevice) {
        onSettingsUpdated => self
    }
    
    func passingRecordRead(_ device: IRCLapRFDevice, record: IRCLapRFDevice.PassingRecord) {
        onPassingRecordRead => (self, record)
    }
    
    func statusUpdated(_ device: IRCLapRFDevice) {
        onStatusUpdated => self
    }
}
