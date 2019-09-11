//
//  IRCLapRFBLEService.swift
//

import IRCSwiftyLapRFCore
import CoreBluetooth
import Signals
import SwiftySensors

open class IRCLapRFBLEService: Service, ServiceProtocol {
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
            // This Request is not correct.
            // let command = IRCLapRFProtocol.resetRTCTime()
            // cbCharacteristic.write(Data(command), writeType: writeType)
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
            if let _ = cbCharacteristic.value {
                // print(data.hexString())
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
                (service?.sensor as? IRCLapRFBLESensor)?.device.ingestData(data)
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


