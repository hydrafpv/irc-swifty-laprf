//
//  IRCLapRFDevice.swift
//

import Foundation

public class IRCLapRFDevice {
    public static let MaxSlots = 16
    
    public static let BLEServiceUUID            = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let BLEControlPointCharUUID   = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let BLEStreamCharUUID         = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    public struct PassingRecord {
        var pilotId: UInt8 = 0
        var passingNumber: UInt32 = 0
        var rtcTime: UInt64 = 0
    }
    var passingRecords: [PassingRecord] = []
    
    public struct RSSIRecord {
        var minRssi: Float = 0
        var maxRssi: Float = 0
        var meanRssi: Float = 0
        var lastRssi: Float = 0
    }
    var rssiPerSlot: [RSSIRecord] = Array(repeating: RSSIRecord(), count: IRCLapRFDevice.MaxSlots) {
        didSet {
        }
    }
    
    public struct RFSetup {
        var enabled: UInt16 = 0
        var channel: UInt16 = 0
        var band: UInt16 = 0
        var gain: UInt16 = calculateGain(racePower: .Tx25mw, sensitivity: .normal)
        var threshold: Float = 900
        var frequency: UInt16 = 0
        
        public enum RacePower: Int {
            case Tx25mw     = 58
            case Tx200mw    = 44
            case Tx350mw    = 40
            case Tx600mw    = 34
        }
        
        public enum Sensitivity: Int {
            case subSub = -4
            case sub    = -2
            case normal = 0
            case add    = 2
            case addAdd = 4
        }
        
        public static func calculateGain(racePower: RacePower, sensitivity: Sensitivity) -> UInt16 {
            return UInt16(max(racePower.rawValue + sensitivity.rawValue, 0))
        }
    }
    
    public fileprivate(set) var rfSetupPerSlot: [RFSetup] = Array(repeating: RFSetup(), count: IRCLapRFDevice.MaxSlots)
    
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
    
    public init() {
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


/*
 Static Protocol Functions.
 */
final public class IRCLapRFProtocol {
    
    private static let SOR: UInt8           = 0x5A
    private static let EOR: UInt8           = 0x5B
    private static let ESC: UInt8           = 0x5C
    private static let ESC_OFFSET: UInt8    = 0x40
    
    private enum RecordType: UInt16 {
        case rssi           = 0xDA01
        case rfSetup        = 0xDA02
        case stateControl   = 0xDA04
        case settings       = 0xDA07
        case passing        = 0xDA09
        case status         = 0xDA0A
        case error          = 0xFFFF
    }
    
    private enum RFSetupField: UInt8 {
        case slotIndex  = 0x01
        case enabled    = 0x20
        case channel    = 0x21
        case band       = 0x22
        case threshold  = 0x23
        case gain       = 0x24
        case frequency  = 0x25
    }
    
    private enum RSSIField: UInt8 {
        case slotIndex  = 0x01
        case minRSSI    = 0x20
        case maxRSSI    = 0x21
        case meanRSSI   = 0x22
        case customRate = 0x24
        case packetRate = 0x25
    }
    
    private enum PassingField: UInt8 {
        case slotIndex      = 0x01
        case rtcTime        = 0x02
        case passingNumber  = 0x21
    }
    
    private enum SettingsField: UInt8 {
        case statusInterval = 0x22
        case minLapTime     = 0x26
    }
    
    private enum StatusField: UInt8 {
        case slotIndex      = 0x01
        case flags          = 0x03
        case batteryVoltage = 0x21
        case lastRSSI       = 0x22
        case gateState      = 0x23
        case detectionCount = 0x24
    }
    
    // must restart the puck after sending this message
    public static func enableBinaryProtocol() -> [UInt8] {
        return [0x55,0x70,0x70,0x0d,0x0a]
    }
    
    // request the RF setup packets from all slots from the gate
    public static func requestRFSetup() -> [UInt8] {
        var bytes = startPacket(.rfSetup)
        for slot in 1 ... 8 {
            bytes.append(contentsOf: UInt8(slot).toBytes(RFSetupField.slotIndex.rawValue))
        }
        return finishPacket(&bytes)
    }
    
    public static func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) -> [UInt8] {
        assert(slot < IRCLapRFDevice.MaxSlots)
        // Convert the 0-based slot indices to (1-MaxSlots)
        // This increment / decrement is hidden and managed inside this class
        var bytes = startPacket(.rfSetup)
        bytes.append(contentsOf: (slot + 1).toBytes(RFSetupField.slotIndex.rawValue))
        bytes.append(contentsOf: config.enabled.toBytes(RFSetupField.enabled.rawValue))
        bytes.append(contentsOf: config.channel.toBytes(RFSetupField.channel.rawValue))
        bytes.append(contentsOf: config.band.toBytes(RFSetupField.band.rawValue))
        bytes.append(contentsOf: config.threshold.toBytes(RFSetupField.threshold.rawValue))
        bytes.append(contentsOf: config.gain.toBytes(RFSetupField.gain.rawValue))
        bytes.append(contentsOf: config.frequency.toBytes(RFSetupField.frequency.rawValue))
        return finishPacket(&bytes)
    }
    
    // set the interval at which the status messages are streamed from the LapRF
    public static func setStatusMessageInterval(_ milliseconds: UInt16) -> [UInt8] {
        var bytes = startPacket(.settings)
        bytes.append(contentsOf: milliseconds.toBytes(SettingsField.statusInterval.rawValue))
        return finishPacket(&bytes)
    }
    
    // set the interval at which the RSSI messages are streamed from the LapRF
    public static func setRSSIPacketRate(_ milliseconds: UInt32) -> [UInt8] {
        var bytes = startPacket(.rssi)
        if milliseconds == 0 {
            bytes.append(contentsOf: UInt8(0).toBytes(RSSIField.customRate.rawValue))
            bytes.append(contentsOf: UInt32(1000).toBytes(RSSIField.packetRate.rawValue))
        } else {
            bytes.append(contentsOf: UInt8(1).toBytes(RSSIField.customRate.rawValue))
            bytes.append(contentsOf: milliseconds.toBytes(RSSIField.packetRate.rawValue))
        }
        return finishPacket(&bytes)
    }
    
    // This function modifies the bytes array passed in
    // ... removing bytes when a complete record is found and processed
    // ... or any stray bytes in front of SOR (Start of Record) byte
    public static func processBytes(_ bytes:inout [UInt8], device: IRCLapRFDevice) {
        while bytes.count > 0 && bytes[0] != SOR {
            // remove bytes until a SOR is found
            bytes.removeFirst()
        }
        if bytes.count > 0 {
            // look for a EOR
            if bytes.contains(EOR) {
                // Good! We have a complete Record.
                // Grab all bytes for a single record and decode it
                // Continue processing the bytes (recursively)
                var buffer: [UInt8] = []
                var byte: UInt8 = 0
                repeat {
                    byte = bytes.removeFirst()
                    buffer.append(byte)
                    if byte == EOR {
                        decodeRecord(buffer, device: device)
                        // process remaining bytes recursively
                        processBytes(&bytes, device: device)
                    }
                } while byte != EOR;
            }
        }
    }
}

/*
 Private functions to encode / decode packets.
 */
fileprivate extension IRCLapRFProtocol {
    
    private static func decodeRecord(_ bytes: [UInt8], device: IRCLapRFDevice) {
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
            var passingRecord: IRCLapRFDevice.PassingRecord?
            if type == .passing {
                passingRecord = IRCLapRFDevice.PassingRecord()
            }
            var recordSlotIndex: UInt8 = 0
            
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
                    case PassingField.slotIndex.rawValue:
                        passingRecord?.pilotId = max(0, packet.readInteger() - 1)// convert to 0-base
                    case PassingField.rtcTime.rawValue:
                        passingRecord?.rtcTime = packet.readInteger()
                        
                        // complete the passing record
                        if let record = passingRecord {
                            device.passingRecords.append(record)
                            passingRecord = nil
                        }
                    case PassingField.passingNumber.rawValue:
                        passingRecord?.passingNumber = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x", type.rawValue, signature))
                    }
                case .rfSetup:
                    switch signature {
                    case RFSetupField.slotIndex.rawValue:
                        recordSlotIndex = max(0, packet.readInteger() - 1)// convert to 0-base
                    case RFSetupField.enabled.rawValue:
                        device.rfSetupPerSlot[Int(recordSlotIndex)].enabled = packet.readInteger()
                    case RFSetupField.channel.rawValue:
                        device.rfSetupPerSlot[Int(recordSlotIndex)].channel = packet.readInteger()
                    case RFSetupField.band.rawValue:
                        device.rfSetupPerSlot[Int(recordSlotIndex)].band = packet.readInteger()
                    case RFSetupField.gain.rawValue:
                        device.rfSetupPerSlot[Int(recordSlotIndex)].gain = packet.readInteger()
                    case RFSetupField.frequency.rawValue:
                        device.rfSetupPerSlot[Int(recordSlotIndex)].frequency = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x", type.rawValue, signature))
                    }
                case .rssi:
                    switch signature {
                    case RSSIField.slotIndex.rawValue:
                        recordSlotIndex = max(0, packet.readInteger() - 1) // convert to 0-base
                    case RSSIField.minRSSI.rawValue:
                        device.rssiPerSlot[Int(recordSlotIndex)].minRssi = packet.readFloat()
                    case RSSIField.maxRSSI.rawValue:
                        device.rssiPerSlot[Int(recordSlotIndex)].maxRssi = packet.readFloat()
                    case RSSIField.meanRSSI.rawValue:
                        device.rssiPerSlot[Int(recordSlotIndex)].meanRssi = packet.readFloat()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x", type.rawValue, signature))
                    }
                case .settings:
                    switch signature {
                    case SettingsField.minLapTime.rawValue:
                        device.minLapTime = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x", type.rawValue, signature))
                    }
                case .status:
                    switch signature {
                    case StatusField.slotIndex.rawValue:
                        recordSlotIndex = max(0, packet.readInteger() - 1) // convert to 0-base
                    case StatusField.flags.rawValue:
                        let _: UInt16 = packet.readInteger()                        
                    case StatusField.batteryVoltage.rawValue:
                        let voltagemV: UInt16 = packet.readInteger()
                        device.batteryVoltage = Float(voltagemV) / 1000.0
                    case StatusField.lastRSSI.rawValue:
                        device.rssiPerSlot[Int(recordSlotIndex)].lastRssi = packet.readFloat()
                    case StatusField.gateState.rawValue:
                        device.gateState = packet.readInteger()
                    case StatusField.detectionCount.rawValue:
                        device.detectionCount = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x", type.rawValue, signature))
                    }
                case .stateControl:
                    switch signature {
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x", type.rawValue, signature))
                    }
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
        let length = UInt16(bytes.count)
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
                unescaped.append(byte - ESC_OFFSET)
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
                escaped.append(byte + ESC_OFFSET)
            } else {
                escaped.append(byte)
            }
        }
        return escaped
    }
    
}

fileprivate extension FixedWidthInteger {
    
    fileprivate func toBytes(_ signature: UInt8) -> [UInt8] {
        // Not the most efficient, but it's not called that often, and makes the above code look nice and clean. :-)
        let byteCount = UInt8(bitWidth / 8)
        var bytes = [signature, byteCount]
        for i in 0 ..< byteCount {
            let shifted = self >> (i * 8)
            bytes.append(UInt8(shifted & 0xFF))
        }
        return bytes
    }
    
}

fileprivate extension Float {
    
    fileprivate func toBytes(_ signature: UInt8) -> [UInt8] {
        var bytes = [signature, 4]
        // This seems very heavy handed to just get the 4 backing bytes of a Float into a Byte Array. :-/
        var copy = Float(self)
        bytes.append(contentsOf: Data(buffer: UnsafeBufferPointer(start: &copy, count: 1)).map {$0})
        return bytes
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
        
        // Assert is not run in production
        assert(unitTest(), "LapRF CRC Algorithm Failure")
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
    
}

/*
 Private Unit Test Function. Only called in Development Mode
 */
fileprivate extension IRCLapRFCRCCalc {
    
    private func unitTest() -> Bool {
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
        return compute(bytes) == 0x1b53
    }
}

