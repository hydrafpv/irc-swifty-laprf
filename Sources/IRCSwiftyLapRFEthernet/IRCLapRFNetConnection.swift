//
//  IRCLapRFNetConnection.swift
//

import IRCSwiftyLapRFCore
import CocoaAsyncSocket
import Foundation
import Signals

open class IRCLapRFNetConnection: NSObject, IRCLapRFConnection, IRCLapRFDeviceDelegate {
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
    
    public var name: String {
        return "\(socketHost):\(socketPort)"
    }
    
    private var socket: GCDAsyncSocket!
    public let socketHost: String
    public let socketPort: UInt16
    public let onConnected = Signal<Bool>()
    public var isConnected: Bool {
        return socket.isConnected
    }
    public init(_ host: String, port: UInt16 = 5403) {
        self.socketHost = host
        self.socketPort = port
        super.init()
        
        device.delegate = self
        
        for _ in 0 ..< IRCLapRFDevice.MaxSlots {
            lastRSSI.append([])
        }
        
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try socket.connect(toHost: host, onPort: port)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    
    @discardableResult public func requestRFSetup() -> Bool {
        let req = IRCLapRFProtocol.requestRFSetup()
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func requestRFSetupForSlot(_ slot: UInt8) -> Bool {
        let req = IRCLapRFProtocol.requestRFSetupForSlot(slot)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func requestRTCTime() -> Bool {
        let req = IRCLapRFProtocol.requestRTCTime(device)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func requestDescriptor() -> Bool {
        let req = IRCLapRFProtocol.requestDescriptor()
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    @discardableResult public func requestSettings() -> Bool {
        let req = IRCLapRFProtocol.requestSettings()
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func resetRTCTime() -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.resetRTCTime()
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.configurePilotSlot(slot, config: config)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func configurePilotSlots(slots: [IRCLapRFDevice.RFSetup]) -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.configurePilotSlots(slots)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func setGateState(_ state: IRCLapRFDevice.GateState) -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.setGateState(state)
        device.gateState = state
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func setMinLapTime(_ milliseconds: UInt32) -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.setMinLapTime(milliseconds)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func setRSSIPacketRate(_ milliseconds: UInt32) -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.setRSSIPacketRate(milliseconds)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
    
    @discardableResult public func setStatusMessageInterval(_ milliseconds: UInt16) -> Bool {
        if readOnly { return false }
        let req = IRCLapRFProtocol.setStatusMessageInterval(milliseconds)
        socket.write(Data(req), withTimeout: -1, tag: 0)
        return true
    }
}

extension IRCLapRFNetConnection: GCDAsyncSocketDelegate {
    public func socketDidDisconnect(_ socket: GCDAsyncSocket, withError err: Error?) {
        onConnected => false
    }
    
    public func socket(_ socket: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        onConnected => true
        requestRFSetup()
        socket.readData(withTimeout: -1, tag: 0)
    }
    
    public func socket(_ socket: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        device.ingestData(data)
        socket.readData(withTimeout: -1, tag: 0)
    }
}
