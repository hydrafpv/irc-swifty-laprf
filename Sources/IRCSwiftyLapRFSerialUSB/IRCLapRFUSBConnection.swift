//
//  IRCLapRFUSBConnection.swift
//

import IRCSwiftyLapRFCore
import Foundation
import ORSSerial

public protocol IRCLapRFUSBDelegate: class {
    func usbConnectionOpened(_ connection: IRCLapRFUSBConnection)
    func usbConnectionClosed(_ connection: IRCLapRFUSBConnection)
}

open class IRCLapRFUSBConnection: NSObject {
    
    public let lapRFDevice: IRCLapRFDevice
    
    private let serialPort: ORSSerialPort?
    public weak var delegate: IRCLapRFUSBDelegate?
    
    public init(_ device: IRCLapRFDevice, serialPortPath: String, delegate: IRCLapRFUSBDelegate? = nil) {
        self.lapRFDevice = device
        self.serialPort = ORSSerialPort(path: serialPortPath)
        self.delegate = delegate
        
        super.init()
        
        serialPort?.delegate = self
        serialPort?.baudRate = 115200
        serialPort?.dtr = true
        serialPort?.rts = true
        serialPort?.open()
    }
    
    deinit {
        serialPort?.delegate = nil
    }
    
    public func enableBinaryProtocol() {
        guard let serialPort = serialPort else { return }
        
        print("Enabling Binary Protocol")
        let bytes = IRCLapRFProtocol.enableBinaryProtocol()
        serialPort.send(Data(bytes))
    }
    
    public func requestRFSetup() {
        guard let serialPort = serialPort else { return }
        print("Requesting Setup")
        let bytes = IRCLapRFProtocol.requestRFSetup()
        serialPort.send(Data(bytes))
    }
    
    public func setRSSIPacketRate(_ milliseconds: UInt32) {
        guard let serialPort = serialPort else { return }
        
        print("Setting RSSI Packet Rate")
        let bytes = IRCLapRFProtocol.setRSSIPacketRate(milliseconds)
        serialPort.send(Data(bytes))
    }
    
    public func setStatusMessageInterval(_ milliseconds: UInt16) {
        guard let serialPort = serialPort else { return }
        
        print("Setting Status Message Interval")
        let bytes = IRCLapRFProtocol.setStatusMessageInterval(milliseconds)
        serialPort.send(Data(bytes))
    }
    
    public func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) {
        guard let serialPort = serialPort else { return }
        
        print("Configuring Pilot Slot")
        let bytes = IRCLapRFProtocol.configurePilotSlot(slot, config: config)
        serialPort.send(Data(bytes))
    }
    
    public func configurePilotSlots(_ slots: [IRCLapRFDevice.RFSetup]) {
        guard let serialPort = serialPort else { return }
        
        print("Configuring Pilot Slots")
        let bytes = IRCLapRFProtocol.configurePilotSlots(slots)
        serialPort.send(Data(bytes))
    }
    
    public func requestRTCTime() {
        guard let serialPort = serialPort else { return }
        
        print("Requesting RTC Time")
        let bytes = IRCLapRFProtocol.requestRTCTime(lapRFDevice)
        serialPort.send(Data(bytes))
    }
    
    public func resetRTCTime() {
        guard let serialPort = serialPort else { return }

        print("Resetting RTC Time")
        let bytes = IRCLapRFProtocol.resetRTCTime()
        serialPort.send(Data(bytes))
    }
    
    public func setGateState(state: IRCLapRFDevice.GateState) {
        guard let serialPort = serialPort else { return }
        
        print("Setting Gate State")
        let bytes = IRCLapRFProtocol.setGateState(state)
        serialPort.send(Data(bytes))
    }
    
    public func setMinLapTime(_ minLapTime: UInt32) {
        guard let serialPort = serialPort else { return }
        
        print("Setting Min Lap Time")
        let bytes = IRCLapRFProtocol.setMinLapTime(minLapTime)
        serialPort.send(Data(bytes))
    }
}

extension IRCLapRFUSBConnection: ORSSerialPortDelegate {
    
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("LapRF Serial Port Removed From System")
        serialPort.delegate = nil
        delegate?.usbConnectionClosed(self)
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        lapRFDevice.ingestData(data)
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("LapRF Serial Port Opened")
        delegate?.usbConnectionOpened(self)
    }
    
}

