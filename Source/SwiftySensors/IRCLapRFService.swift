//
//  IRCLapRFService.swift
//

import SwiftySensors
import CoreBluetooth

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
    
    var controlPoint: ControlPoint? { return characteristic() }
    var stream: Stream? { return characteristic() }
    
    open class ControlPoint: Characteristic {
        public static let uuid: String = IRCLapRFDevice.BLEControlPointCharUUID
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
            cbCharacteristic.notify(true)
        }
        
        override open func valueUpdated() {
            if let data = cbCharacteristic.value {
               print(data.map{$0})
            }
            super.valueUpdated()
        }
        
        func requestSetup() {
            let command = IRCLapRFProtocol.requestRFSetup()
            print(command)
            cbCharacteristic.write(Data(bytes:command), writeType: .withResponse)
        }
        
    }
    
    open class Stream: Characteristic {
        public static let uuid: String = IRCLapRFDevice.BLEStreamCharUUID
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            readValue()
            cbCharacteristic.notify(true)
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
