//
//  LapRFConnection.swift
//

import Foundation
import Signals

public class IRCLapRFDevice {
    public static let MaxSlots = 16
    
    struct PassingRecord {
        var pilotId: UInt8 = 0
        var passingNumber: UInt32 = 0
        var rtcTime: UInt64 = 0
    }
    var passingRecords: [PassingRecord] = []
    
    struct RSSIRecord {
        var minRssi: Float = 0
        var maxRssi: Float = 0
        var meanRssi: Float = 0
        var lastRssi: Float = 0
    }
    var rssiPerSlot: [RSSIRecord] = Array(repeating: RSSIRecord(), count: IRCLapRFDevice.MaxSlots) {
        didSet {
        }
    }
    
    struct RFSetup {
        var enabled: UInt16 = 0
        var channel: UInt16 = 0
        var band: UInt16 = 0
        var attenuation: UInt16 = 0
        var frequency: UInt16 = 0
    }
    var rfSetupPerSlot: [RFSetup] = Array(repeating: RFSetup(), count: IRCLapRFDevice.MaxSlots)
    
    public fileprivate(set) var batteryVoltage: Float = 0 {
        didSet {
        }
    }
    public fileprivate(set) var gateState: UInt8 = 0 {
        didSet {
        }
    }
    public fileprivate(set) var detectionCount: UInt32 = 0 {
        didSet {
        }
    }
    public fileprivate(set) var minLapTime: UInt32 = 0 {
        didSet {
        }
    }
    
    init() {
        let _ = IRCLapRFCRCCalc.instance
    }
    
    private var buffer: [UInt8] = []
    public func ingestBytes(_ bytes: [UInt8]) {
        buffer.append(contentsOf: bytes)
        IRCLapRFProtocol.processBytes(&buffer, device: self)
    }
    
    public func ingestData(_ data: Data) {
        buffer.append(contentsOf: data.map{$0})
        IRCLapRFProtocol.processBytes(&buffer, device: self)
    }
}

final public class IRCLapRFProtocol {
    
    private static let SOR: UInt8 = 0x5A
    private static let EOR: UInt8 = 0x5B
    private static let ESC: UInt8 = 0x5C
    
    private enum RecordType: UInt16 {
        case rssi = 0xDA01
        case rfSetup = 0xDA02
        case stateControl = 0xDA04
        case settings = 0xDA07
        case passing = 0xDA09
        case status = 0xDA0A
        case error = 0xFFFF
    }
    
    // must restart the puck after sending this message
    public static func enableBinaryProtocol() -> [UInt8] {
        return [0x55,0x70,0x70, 0x0d, 0x0a]
    }
    
    // request the RF setup packets from all slots from the gate
    public static func requestRFSetup() -> [UInt8] {
        var bytes = startPacket(.rfSetup)
        for i in 1 ... 8 {
            bytes.append(contentsOf: bytesFor8Record(0x01, data: UInt8(i)))
        }
        return finishPacket(&bytes)
    }
    
    public static func setPilotSlot(_ index: UInt8, enabled: Bool, freqMHz: UInt16) -> [UInt8] {
        var bytes = startPacket(.rfSetup)
        bytes.append(contentsOf: bytesFor8Record(0x01, data: index))
        if enabled {
            bytes.append(contentsOf: bytesFor16Record(0x20, data: 0x01))
        } else {
            bytes.append(contentsOf: bytesFor16Record(0x20, data: 0x00))
        }
        bytes.append(contentsOf: bytesFor16Record(0x25, data: freqMHz))
        return finishPacket(&bytes)
    }
    
    // set the interval at which the status messages are streamed from the LapRF
    public static func setStatusMessageInterval(_ milliseconds: UInt16) -> [UInt8] {
        var bytes = startPacket(.settings)
        bytes.append(contentsOf: bytesFor16Record(0x22, data: milliseconds))
        return finishPacket(&bytes)
    }
    
    // set the interval at which the RSSI messages are streamed from the LapRF
    public static func setRSSIPacketRate(_ milliseconds: UInt32) -> [UInt8] {
        var bytes = startPacket(.rssi)
        if milliseconds == 0 {
            bytes.append(contentsOf: bytesFor8Record(0x24, data: 0))
            bytes.append(contentsOf: bytesFor32Record(0x25, data: 1000))
        } else {
            bytes.append(contentsOf: bytesFor8Record(0x24, data: 1))
            bytes.append(contentsOf: bytesFor32Record(0x25, data: milliseconds))
        }
        return finishPacket(&bytes)
    }
    
    public static func processBytes(_ bytes:inout [UInt8], device: IRCLapRFDevice) {
        while bytes.count > 0 && bytes[0] != SOR {
            // remove bytes until a SOR is found
            bytes.removeFirst()
        }
        if bytes.count > 0 {
            // look for a EOR
            if bytes.contains(EOR) {
                // Good! we have a complete Record.
                var buffer: [UInt8] = []
                var byte: UInt8 = 0
                repeat {
                    byte = bytes.removeFirst()
                    buffer.append(byte)
                    if byte == EOR {
                        decodePacket(buffer, device: device)
                        // process remaining bytes again
                        processBytes(&bytes, device: device)
                    }
                } while byte != EOR;
            }
        }
    }
}

fileprivate extension IRCLapRFProtocol {
    
    private static func decodePacket(_ bytes: [UInt8], device: IRCLapRFDevice) {
        var packet = unescapeBytes(bytes)
        if packet.count < 8 {
            return
        }
        let sor = packet[0]
        if sor != SOR {
            return
        }
        let _ = UInt16(packet[1]) | UInt16(packet[2]) << 8
        let crc = UInt16(packet[3]) | UInt16(packet[4]) << 8
        packet[3] = 0
        packet[4] = 0
        let crc2 = IRCLapRFCRCCalc.instance.compute(packet)
        if crc != crc2 {
            return
        }
        let typeRaw = UInt16(packet[5]) | UInt16(packet[6]) << 8
        if let type = RecordType(rawValue: typeRaw) {
            packet.removeFirst(7)
            print("Processing Packet Type: \(type)")
            var passingRecord: IRCLapRFDevice.PassingRecord?
            if type == .passing {
                passingRecord = IRCLapRFDevice.PassingRecord()
            }
            var setupRecordId: UInt8 = 0
            var currentRssiSlot: UInt8 = 0
            
            // all bytes in between SOR and EOR are grouped into individual records
            while packet.count > 3 {
                let signature = packet.removeFirst()
                let size = packet.removeFirst() // number of bytes
                if size > packet.count {
                    return  // bad bad bad packet.
                }
                
                switch type {
                case .error:
                    break
                case .passing:
                    switch signature {
                    case 0x01:
                        passingRecord?.pilotId = packet.readInteger()
                    case 0x21:
                        passingRecord?.passingNumber = packet.readInteger()
                    case 0x02:
                        passingRecord?.rtcTime = packet.readInteger()
                        
                        // complete the passing record
                        if let record = passingRecord {
                            device.passingRecords.append(record)
                            passingRecord = nil
                        }
                    default:
                        break
                    }
                case .rfSetup:
                    switch signature {
                    case 0x01:
                        setupRecordId = packet.readInteger() - 1 // convert to 0-base
                    case 0x20:
                        device.rfSetupPerSlot[Int(setupRecordId)].enabled = packet.readInteger()
                    case 0x21:
                        device.rfSetupPerSlot[Int(setupRecordId)].channel = packet.readInteger()
                    case 0x22:
                        device.rfSetupPerSlot[Int(setupRecordId)].band = packet.readInteger()
                    case 0x24:
                        device.rfSetupPerSlot[Int(setupRecordId)].attenuation = packet.readInteger()
                    case 0x25:
                        device.rfSetupPerSlot[Int(setupRecordId)].frequency = packet.readInteger()
                    default:
                        break
                    }
                case .rssi:
                    switch signature {
                    case 0x01:
                        currentRssiSlot = packet.readInteger() - 1 // convert to 0-base
                    case 0x20:
                        device.rssiPerSlot[Int(currentRssiSlot)].minRssi = packet.readFloat()
                    case 0x21:
                        device.rssiPerSlot[Int(currentRssiSlot)].maxRssi = packet.readFloat()
                    case 0x22:
                        device.rssiPerSlot[Int(currentRssiSlot)].meanRssi = packet.readFloat()
                    case 0x07:
                        // TBD
                        break
                    default:
                        break
                    }
                case .settings:
                    switch signature {
                    case 0x26:
                        device.minLapTime = packet.readInteger()
                    default:
                        break
                    }
                case .status:
                    switch signature {
                    case 0x01:
                        currentRssiSlot = packet.readInteger() - 1
                    case 0x03:
                        let _: UInt16 = packet.readInteger()
                    case 0x21:
                        let voltagemV: UInt16 = packet.readInteger()
                        device.batteryVoltage = Float(voltagemV) / 1000.0
                    case 0x22:
                        device.rssiPerSlot[Int(currentRssiSlot)].lastRssi = packet.readFloat()
                    case 0x23:
                        device.gateState = packet.readInteger()
                    case 0x24:
                        device.detectionCount = packet.readInteger()
                    default:
                        break
                    }
                case .stateControl:
                    break
                }
                packet.removeFirst(Int(size))
            }
            
        }
    }
    
    private static func startPacket(_ type: RecordType) -> [UInt8] {
        return [SOR, 0, 0, 0, 0, UInt8(type.rawValue & 0xFF), UInt8(type.rawValue >> 8 & 0xFF)]
    }
    
    private static func finishPacket(_ bytes:inout [UInt8]) -> [UInt8] {
        bytes.append(EOR)
        let length: UInt16 = UInt16(bytes.count)
        bytes[1] = UInt8(length & 0xFF)
        bytes[2] = UInt8(length >> 8 & 0xFF)
        let crc = IRCLapRFCRCCalc.instance.compute(bytes)
        bytes[3] = UInt8(crc & 0xFF)
        bytes[4] = UInt8(crc >> 8 & 0xFF)
        return escapeBytes(bytes)
    }
    
    private static func unescapeBytes(_ bytes: [UInt8]) -> [UInt8] {
        var unescaped: [UInt8] = []
        var escaped = false
        for byte in bytes {
            if byte == ESC {
                escaped = true
            } else if escaped {
                unescaped.append(byte - 0x40)
                escaped = false
            } else {
                unescaped.append(byte)
            }
        }
        return unescaped
    }
    
    private static func escapeBytes(_ bytes: [UInt8]) -> [UInt8] {
        var escaped: [UInt8] = []
        for (i, byte) in bytes.enumerated() {
            if (byte == SOR || byte == EOR || byte == ESC) && i != 0 && i != bytes.count - 1 {
                escaped.append(ESC)
                escaped.append(byte + 0x40)
            } else {
                escaped.append(byte)
            }
        }
        return escaped
    }
    
    private static func bytesFor8Record(_ signature: UInt8, data: UInt8) -> [UInt8] {
        return [signature, 1, data]
    }
    
    private static func bytesFor16Record(_ signature: UInt8, data: UInt16) -> [UInt8] {
        return [signature, 2, UInt8(data & 0xFF), UInt8(data >> 8 & 0xFF)]
    }
    
    private static func bytesFor32Record(_ signature: UInt8, data: UInt32) -> [UInt8] {
        return [signature, 4, UInt8(data & 0xFF), UInt8(data >> 8 & 0xFF), UInt8(data >> 16 & 0xFF), UInt8(data >> 24 & 0xFF)]
    }
    
}








fileprivate final class IRCLapRFCRCCalc {
    static let instance = IRCLapRFCRCCalc()
    private var crc16_table: [UInt16] = Array(repeating: 0, count: 256)
    
    private init() {
        var remainder: UInt16 = 0
        
        for i in 0 ..< 256 {
            remainder = UInt16(i << 8) & 0xFF00
            for _ in stride(from: 8, to: 0, by: -1) {
                if remainder & 0x8000 == 0x8000 {
                    remainder = ((remainder << 1) & 0xFFFF) ^ 0x8005
                } else {
                    remainder = (remainder << 1) & 0xFFFF
                }
            }
            crc16_table[i] = remainder
        }
        
        unitTest()
    }
    
    private func reflect(_ input: UInt16, nbits: Int) -> UInt16 {
        var shift = input
        var output: UInt16 = 0
        for i in 0 ..< nbits {
            if shift & 0x01 == 0x01 {
                output |= (1 << ((nbits - 1) - i))
            }
            shift = shift >> 1
        }
        return output
    }
    
    fileprivate func compute(_ dataIn: [UInt8]) -> UInt16 {
        var remainder: UInt16 = 0
        for i in 0 ..< dataIn.count {
            var a = reflect(UInt16(dataIn[i]), nbits: 8)
            a &= 0xFF
            let b = (remainder >> 8) & 0xFF
            let c = (remainder << 8) & 0xFFFF
            let data = a ^ b
            remainder = crc16_table[Int(data)] ^ c
        }
        return reflect(remainder, nbits: 16)
    }
    
    private func unitTest() {
        let bytes: [UInt8] = [
            0x5a,0x3d,0x00,0x00,0x00,0x0a,0xda,0x21,
            0x02,0x3c,0x0d,0x23,0x01,0x01,0x24,0x04,
            0x00,0x00,0x00,0x00,0x01,0x01,0x01,0x22,
            0x04,0x00,0x80,0x62,0x44,0x01,0x01,0x02,
            0x22,0x04,0x00,0x00,0x62,0x44,0x01,0x01,
            0x03,0x22,0x04,0x00,0x80,0x6a,0x44,0x01,
            0x01,0x04,0x22,0x04,0x00,0x00,0x62,0x44,
            0x03,0x02,0x00,0x00,0x5b
        ]
        
        let retVal = compute(bytes);
        if retVal != 0x1b53 {
            print("MISMATCH")
        }
    }
}

