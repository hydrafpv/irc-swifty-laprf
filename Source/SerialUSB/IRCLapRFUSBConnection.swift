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
    
    public func enableBinaryProtocol() {
        guard let serialPort = serialPort else { return }
        
        let bytes = IRCLapRFProtocol.enableBinaryProtocol()
        serialPort.send(Data(bytes: bytes))
    }
}

extension IRCLapRFUSBConnection: ORSSerialPortDelegate {
    
    public func serialPortWasRemoved(fromSystem serialPort: ORSSerialPort) {
        serialPort.delegate = nil
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        lapRFDevice.ingestData(data)
//        print(lapRFDevice.rfSetupPerSlot)
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
//        let bytes = IRCLapRFProtocol.requestRFSetup()
//        serialPort.send(Data(bytes: bytes))
//        enableBinaryProtocol()
//        let bytes2 = IRCLapRFProtocol.setRSSIPacketRate(1000)
        let bytes2 = IRCLapRFProtocol.setStatusMessageInterval(50)
        serialPort.send(Data(bytes: bytes2))
    }
    
}

