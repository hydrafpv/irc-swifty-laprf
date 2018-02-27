//
//  IRCLapRFUSBConnection.swift
//

import Foundation
import ORSSerial


final class IRCLapRFUSBConnection: NSObject {
    
    var device: IRCLapRFDevice!
    
    let serialPort = ORSSerialPort(path: "/dev/cu.usbmodem14611")
    init(_ device: IRCLapRFDevice) {
        super.init()
        
        self.device = device
        serialPort?.delegate = self
        serialPort?.baudRate = 115200
        serialPort?.dtr = true
        serialPort?.rts = true
        serialPort?.open()
    }
    
}


extension IRCLapRFUSBConnection: ORSSerialPortDelegate {
    
    func serialPortWasRemoved(fromSystem serialPort: ORSSerialPort) {
        
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        device.ingestData(data)
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        let bytes = IRCLapRFProtocol.requestRFSetup()
        serialPort.send(Data(bytes: bytes))
    }
    
}

