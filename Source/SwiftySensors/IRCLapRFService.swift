//
//  IRCLapRFService.swift
//

import CoreBluetooth
import Signals
import SwiftySensors

open class IRCLapRFService: Service, ServiceProtocol {
    public static let uuid: String = IRCLapRFDevice.BLEServiceUUID
    public static var characteristicTypes: Dictionary<String, Characteristic.Type> = [
        ControlPoint.uuid:  ControlPoint.self,
        Stream.uuid:        Stream.self,
        BaudRate.uuid:      BaudRate.self,
        Parity.uuid:        Parity.self,
        FlowControl.uuid:   FlowControl.self,
        Enable.uuid:        Enable.self
        ]
    
    public var controlPoint: ControlPoint? { return characteristic(IRCLapRFDevice.BLEControlPointCharUUID) }
    
    open class ControlPoint: Characteristic {
        public static let uuid: String = IRCLapRFDevice.BLEControlPointCharUUID
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
            cbCharacteristic.notify(true)
        }
        private let writeType: CBCharacteristicWriteType = .withoutResponse
        private func writeChunks(_ command: inout [UInt8]) {
            var chunk: [UInt8] = []
            while command.count > 0 {
                chunk.removeAll()
                while chunk.count < 20, command.count > 0 {
                    chunk.append(command.removeFirst())
                }
                cbCharacteristic.write(Data(chunk), writeType: writeType)
            }
        }
        
        
        
        public func requestDescriptor() {
            var command = IRCLapRFProtocol.requestDescriptor()
            writeChunks(&command)
        }
        
        public func requestRFSetup() {
            var command = IRCLapRFProtocol.requestRFSetup()
            writeChunks(&command)
        }
        
        public func requestSettings() {
            var command = IRCLapRFProtocol.requestSettings()
            writeChunks(&command)
        }
        
        public func requestRFSetupForSlot(_ slot: UInt8) {
            var command = IRCLapRFProtocol.requestRFSetupForSlot(slot)
            writeChunks(&command)
        }
        
        public func requestRTCTime(_ device: IRCLapRFDevice) {
            var command = IRCLapRFProtocol.requestRTCTime(device)
            writeChunks(&command)
        }
        
        public func resetRTCTime() {
//            let command = IRCLapRFProtocol.resetRTCTime()
//            cbCharacteristic.write(Data(command), writeType: writeType)
        }
        
        public func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) {
            var command = IRCLapRFProtocol.configurePilotSlot(slot, config: config)
            writeChunks(&command)
        }
        
        public func configurePilotSlots(_ slots: [IRCLapRFDevice.RFSetup]) {
            var command = IRCLapRFProtocol.configurePilotSlots(slots)
            writeChunks(&command)
        }
        
        public func setGateState(_ state: IRCLapRFDevice.GateState) {
            var command = IRCLapRFProtocol.setGateState(state)
            writeChunks(&command)
        }
        
        public func setMinLapTime(_ milliseconds: UInt32) {
            var command = IRCLapRFProtocol.setMinLapTime(milliseconds)
            writeChunks(&command)
        }
        
        public func setRSSIPacketRate(_ milliseconds: UInt32) {
            var command = IRCLapRFProtocol.setRSSIPacketRate(milliseconds)
            writeChunks(&command)
        }
        
        public func setStatusMessageInterval(_ milliseconds: UInt16) {
            var command = IRCLapRFProtocol.setStatusMessageInterval(milliseconds)
            writeChunks(&command)
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
//                print(data.hexString())
            }
            super.valueUpdated()
        }
        
    }
    
    open class Stream: Characteristic {
        public static let uuid: String = IRCLapRFDevice.BLEStreamCharUUID
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
            cbCharacteristic.notify(true)
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
                (service?.sensor as? IRCSensor)?.device.ingestData(data)
            }
            super.valueUpdated()
        }
    }
    
    open class BaudRate: Characteristic {
        public static let uuid: String = "6E400004-B5A3-F393-E0A9-E50E24DCCA9E"
        
        public private(set) var baudRate: UInt32 = 115200
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
                baudRate = data.map{$0}.readInteger()
            }
            super.valueUpdated()
        }
    }
    
    open class Parity: Characteristic {
        public static let uuid: String = "6E400005-B5A3-F393-E0A9-E50E24DCCA9E"
        
        public private(set) var parity: UInt8 = 0
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
                parity = data.map{$0}.readInteger()
            }
            super.valueUpdated()
        }
    }
    
    open class FlowControl: Characteristic {
        public static let uuid: String = "6E400006-B5A3-F393-E0A9-E50E24DCCA9E"
        
        public private(set) var flowControl: UInt8 = 0
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
                flowControl = data.map{$0}.readInteger()
            }
            super.valueUpdated()
        }
    }
    
    open class Enable: Characteristic {
        public static let uuid: String = "6E400008-B5A3-F393-E0A9-E50E24DCCA9E"
        
        public private(set) var enabled: UInt8 = 0
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
                enabled = data.map{$0}.readInteger()
            }
            super.valueUpdated()
        }
    }
}







open class IRCSensor: Sensor {
    
    public let device = IRCLapRFDevice()
    
    // One-To-Many Messaging
    public let onRSSIRangeUpdated = Signal<(IRCSensor, UInt8)>()
    public let onRFSetupRead = Signal<(IRCSensor, UInt8)>()
    public let onTimeUpdated = Signal<IRCSensor>()
    public let onSettingsUpdated = Signal<IRCSensor>()
    public let onStatusUpdated = Signal<IRCSensor>()
    public let onPassingRecordRead = Signal<(IRCSensor, IRCLapRFDevice.PassingRecord)>()
    
    public private(set) var lastRSSI:[[Float]] = []
    
    // Quick Access to IRC Service and Control Point
    private var ircService: IRCLapRFService? { return service(IRCLapRFService.uuid) }
    private var controlPoint: IRCLapRFService.ControlPoint? { return ircService?.controlPoint }
    
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
        guard let cp = controlPoint else { return false }
        cp.resetRTCTime()
        return true
    }
    
    @discardableResult public func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) -> Bool {
        guard let cp = controlPoint else { return false }
        cp.configurePilotSlot(slot, config: config)
        return true
    }
    
    @discardableResult public func configurePilotSlots(slots: [IRCLapRFDevice.RFSetup]) -> Bool {
        guard let cp = controlPoint else { return false }
        cp.configurePilotSlots(slots)
        return true
    }
    
    @discardableResult public func setGateState(_ state: IRCLapRFDevice.GateState) -> Bool {
        guard let cp = controlPoint else { return false }
        device.gateState = state
        cp.setGateState(state)
        return true
    }
    
    @discardableResult public func setMinLapTime(_ milliseconds: UInt32) -> Bool {
        guard let cp = controlPoint else { return false }
        cp.setMinLapTime(milliseconds)
        return true
    }
    
    @discardableResult public func setRSSIPacketRate(_ milliseconds: UInt32) -> Bool {
        guard let cp = controlPoint else { return false }
        cp.setRSSIPacketRate(milliseconds)
        return true
    }
    
    @discardableResult public func setStatusMessageInterval(_ milliseconds: UInt16) -> Bool {
        guard let cp = controlPoint else { return false }
        cp.setStatusMessageInterval(milliseconds)
        return true
    }
    
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
}

extension IRCSensor: IRCLapRFDeviceDelegate {
    public func rssiRangeUpdated(_ device: IRCLapRFDevice, slot: UInt8) {
        let rssi = device.rssiPerSlot[Int(slot)]
        lastRSSI[Int(slot)].append(rssi.lastRssi)
        while lastRSSI[Int(slot)].count > 120 {
            lastRSSI[Int(slot)].removeFirst()
        }
        onRSSIRangeUpdated => (self, slot)
    }

    public func rfSetupRead(_ device: IRCLapRFDevice, slot: UInt8) {
        onRFSetupRead => (self, slot)
    }

    public func timeUpdated(_ device: IRCLapRFDevice) {
        onTimeUpdated => self
    }
    
    public func settingsUpdated(_ device: IRCLapRFDevice) {
        onSettingsUpdated => self
    }

    public func passingRecordRead(_ device: IRCLapRFDevice, record: IRCLapRFDevice.PassingRecord) {
        onPassingRecordRead => (self, record)
    }

    public func statusUpdated(_ device: IRCLapRFDevice) {
        onStatusUpdated => self
    }

}
