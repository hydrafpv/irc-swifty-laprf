//
//  IRCLapRFUSBConnection.swift
//

import Foundation
import ORSSerial

open class IRCLapRFUSBConnection: NSObject {
    
    public let lapRFDevice: IRCLapRFDevice
    
    private var serialPort: ORSSerialPort?
    
    public init(_ device: IRCLapRFDevice, serialPortPath: String) {
        lapRFDevice = device
        serialPort = ORSSerialPort(path: serialPortPath)
        
        super.init()
        
        serialPort?.delegate = self
        serialPort?.baudRate = 115200
        serialPort?.dtr = true
        serialPort?.rts = true
        serialPort?.open()
    }
    
}

extension IRCLapRFUSBConnection: ORSSerialPortDelegate {
    
    public func serialPortWasRemoved(fromSystem serialPort: ORSSerialPort) {
        
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        lapRFDevice.ingestData(data)
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        let bytes = IRCLapRFProtocol.requestRFSetup()
        serialPort.send(Data(bytes: bytes))
    }
    
}

