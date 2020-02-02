//
//  IRCLapRFBLESensor.swift
//

import IRCSwiftyLapRFCore
import CoreBluetooth
import Signals
import SwiftySensors

open class IRCLapRFBLESensor: Sensor, IRCLapRFConnection, IRCLapRFDeviceDelegate {
    
    public let device = IRCLapRFDevice()
    
    // One-To-Many Messaging
    public let onRSSIRangeUpdated = Signal<(IRCLapRFConnection, UInt8)>()
    public let onRFSetupRead = Signal<(IRCLapRFConnection, UInt8)>()
    public let onTimeUpdated = Signal<IRCLapRFConnection>()
    public let onSettingsUpdated = Signal<IRCLapRFConnection>()
    public let onStatusUpdated = Signal<IRCLapRFConnection>()
    public let onPassingRecordRead = Signal<(IRCLapRFConnection, IRCLapRFDevice.PassingRecord)>()
    
    public var lastRSSI:[[Float]] = []
    public var readOnly: Bool = false
    
    // Quick Access to IRC Service and Control Point
    private var ircService: IRCLapRFBLEService? { return service(IRCLapRFBLEService.uuid) }
    private var controlPoint: IRCLapRFBLEService.ControlPoint? { return ircService?.controlPoint }
    
    public var name: String {
        return peripheral.name ?? "Nameless"
    }    
    
    public required init(peripheral: CBPeripheral, advertisements: [CBUUID] = []) {
        super.init(peripheral: peripheral, advertisements: advertisements)
        device.delegate = self
        
        for _ in 0 ..< IRCLapRFDevice.MaxSlots {
            lastRSSI.append([])
        }
    }

    @discardableResult public func requestRFSetup() -> Bool {
        guard let cp = controlPoint else { return false }
        cp.requestRFSetup()
        return true
    }
    
    @discardableResult public func requestRFSetupForSlot(_ slot: UInt8) -> Bool {
        guard let cp = controlPoint else { return false }
        cp.requestRFSetupForSlot(slot)
        return true
    }
    
    @discardableResult public func requestRTCTime() -> Bool {
        guard let cp = controlPoint else { return false }
        cp.requestRTCTime(device)
        return true
    }
    
    @discardableResult public func requestDescriptor() -> Bool {
        guard let cp = controlPoint else { return false }
        cp.requestDescriptor()
        return true
    }
    @discardableResult public func requestSettings() -> Bool {
        guard let cp = controlPoint else { return false }
        cp.requestSettings()
        return true
    }
    
    @discardableResult public func resetRTCTime() -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        cp.resetRTCTime()
        return true
    }
    
    @discardableResult public func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        cp.configurePilotSlot(slot, config: config)
        return true
    }
    
    @discardableResult public func configurePilotSlots(slots: [IRCLapRFDevice.RFSetup]) -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        cp.configurePilotSlots(slots)
        return true
    }
    
    @discardableResult public func setGateState(_ state: IRCLapRFDevice.GateState) -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        device.gateState = state
        cp.setGateState(state)
        return true
    }
    
    @discardableResult public func setMinLapTime(_ milliseconds: UInt32) -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        cp.setMinLapTime(milliseconds)
        return true
    }
    
    @discardableResult public func setRSSIPacketRate(_ milliseconds: UInt32) -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        cp.setRSSIPacketRate(milliseconds)
        return true
    }
    
    @discardableResult public func setStatusMessageInterval(_ milliseconds: UInt16) -> Bool {
        guard let cp = controlPoint, !readOnly else { return false }
        cp.setStatusMessageInterval(milliseconds)
        return true
    }

}
