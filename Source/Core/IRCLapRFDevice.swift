//
//  IRCLapRFDevice.swift
//

import Foundation

public protocol IRCLapRFDeviceDelegate: class {
    func rssiRangeUpdated(_ device: IRCLapRFDevice, slot: UInt8)
    func rfSetupRead(_ device: IRCLapRFDevice, slot: UInt8)
    func settingsUpdated(_ device: IRCLapRFDevice)
    func timeUpdated(_ device: IRCLapRFDevice)
    func passingRecordRead(_ device: IRCLapRFDevice, record: IRCLapRFDevice.PassingRecord)
    func statusUpdated(_ device: IRCLapRFDevice)
}

public class IRCLapRFDevice: NSObject {
    
    public enum GateState: UInt8 {
        case idle       = 0x00
        case active     = 0x01
        case crashed    = 0x02
        case shutdown   = 0xFE // Reset?
    }
    
    public static let USBVendorId = 0x04d8
    public static let USBProductId = 0x000a
    
    public static let MaxSlots = 8
    
    public static let BLEServiceUUID            = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let BLEControlPointCharUUID   = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let BLEStreamCharUUID         = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    public struct PassingRecord {
        public fileprivate(set) var decoderId: UInt32 = 0
        public fileprivate(set) var pilotId: UInt8 = 0
        public fileprivate(set) var passingNumber: UInt32 = 0
        public fileprivate(set) var rtcTime: UInt64 = 0
        public fileprivate(set) var flags: UInt16 = 0
        public fileprivate(set) var peakHeight: UInt16 = 0
        public var rtcTimeSeconds: TimeInterval {
            return Double(rtcTime) / (1000 * 1000)
        }
        public fileprivate(set) var rtcTimeLocalSeconds: TimeInterval = 0
    }
    public fileprivate(set) var passingRecords: [PassingRecord] = []
    
    public class RSSIRecord {
        public var minRssi: Float = 0
        public var maxRssi: Float = 0
        public var meanRssi: Float = 0
        public var lastRssi: Float = 0
    }
    public fileprivate(set) var rssiPerSlot: [RSSIRecord] = []
    
    public class RFSetup {
        public var enabled: UInt16 = 0
        public var channel: UInt16 = 0
        public var band: UInt16 = 0
        public var gain: UInt16 = calculateGain(racePower: .tx25mw, sensitivity: .normal)
        public var threshold: Float = 900
        public var frequency: UInt16 = 0
        
        public enum RacePower: Int {
            case tx25mw     = 58
            case tx200mw    = 44
            case tx350mw    = 40
            case tx600mw    = 34
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
        public init() {
            
        }
    }
    
    public var rfSetupPerSlot: [RFSetup] = []
    
    public var batteryVoltage: Float = 0
    public var gateState: GateState = .idle
    public var detectionCount: UInt32 = 0
    public var minLapTime: UInt32 = 0
    public var statusFlags: UInt16 = 0
    public var rtcTime: UInt64 = 0 {
        didSet {
            if let requestTime = rtcRequest {
                let now = Date()
                let lt = now.timeIntervalSince(requestTime) * 0.5
                rtcTimeLocalSeconds = now.addingTimeInterval(-lt).timeIntervalSince1970 - rtcTimeSeconds
                print("Calculated Local RTC Time")
                rtcRequest = nil
            }
        }
    }
    public var timeRtcTime: UInt64 = 0
    
    public var rtcTimeSeconds: TimeInterval {
        return Double(rtcTime) / (1000 * 1000)
    }
    public private(set) var rtcTimeLocalSeconds: TimeInterval = 0
    
    public var timeRtcTimeSeconds: TimeInterval {
        return Double(timeRtcTime) / (1000 * 1000)
    }
    
    public var tag: Int = 0
    
    public weak var delegate: IRCLapRFDeviceDelegate?
    public init(_ delegate: IRCLapRFDeviceDelegate? = nil) {
        let _ = IRCLapRFCRCCalc.instance
        for _ in 0 ..< IRCLapRFDevice.MaxSlots {
            rfSetupPerSlot.append(RFSetup())
            rssiPerSlot.append(RSSIRecord())
        }
        self.delegate = delegate
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
    
    fileprivate var rtcRequest: Date?
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
        case descriptor     = 0xDA08
        case passing        = 0xDA09
        case status         = 0xDA0A
        case time           = 0xDA0C
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
        case unknown1   = 0x23
        case customRate = 0x24
        case packetRate = 0x25
        case unknown2   = 0x26
    }
    
    private enum PassingField: UInt8 {
        case slotIndex      = 0x01
        case rtcTime        = 0x02
        case decoderId      = 0x20
        case passingNumber  = 0x21
        case peakHeight     = 0x22
        case flags          = 0x23
    }
    
    private enum SettingsField: UInt8 {
        case statusInterval = 0x22
        case minLapTime     = 0x26
    }
    
    private enum StateControlField: UInt8 {
        case gateState  = 0x20
    }
    
    private enum StatusField: UInt8 {
        case slotIndex      = 0x01
        case flags          = 0x03
        case batteryVoltage = 0x21
        case lastRSSI       = 0x22
        case gateState      = 0x23
        case detectionCount = 0x24
    }
    
    private enum TimeField: UInt8 {
        case rtcTime        = 0x02
        case timeRtcTime    = 0x20
    }
    
    // must restart the puck after sending this message
    public static func enableBinaryProtocol() -> [UInt8] {
        return [0x55,0x70,0x70,0x0d,0x0a]
    }
    
    // request the Timer Protocol and Version Info
    public static func requestDescriptor() -> [UInt8] {
        var bytes = startPacket(.descriptor)
        return finishPacket(&bytes)
    }
    
    // request the RF setup packets from all slots from the gate
    public static func requestRFSetup() -> [UInt8] {
        var bytes = startPacket(.rfSetup)
        for slot in 1 ... 8 {
            bytes.append(contentsOf: UInt8(slot).toBytes(RFSetupField.slotIndex.rawValue))
        }
        return finishPacket(&bytes)
    }

    public static func requestSettings() -> [UInt8] {
        var bytes = startPacket(.settings)
        bytes.append(SettingsField.minLapTime.rawValue)
        bytes.append(0x00)
        return finishPacket(&bytes)
    }
    
    public static func requestRFSetupForSlot(_ slot: UInt8) -> [UInt8] {
        var bytes = startPacket(.rfSetup)
        bytes.append(contentsOf: UInt8(slot + 1).toBytes(RFSetupField.slotIndex.rawValue))
        return finishPacket(&bytes)
    }
    
    public static func configurePilotSlot(_ slot: UInt8, config: IRCLapRFDevice.RFSetup) -> [UInt8] {
        assert(slot < IRCLapRFDevice.MaxSlots)
        // Convert the 0-based slot indices to (1-MaxSlots)
        // This increment / decrement is hidden and managed inside this class
        var bytes = startPacket(.rfSetup)
        bytes.append(contentsOf: UInt8(slot + 1).toBytes(RFSetupField.slotIndex.rawValue))
        bytes.append(contentsOf: config.enabled.toBytes(RFSetupField.enabled.rawValue))
        bytes.append(contentsOf: config.channel.toBytes(RFSetupField.channel.rawValue))
        bytes.append(contentsOf: config.band.toBytes(RFSetupField.band.rawValue))
        bytes.append(contentsOf: config.threshold.toBytes(RFSetupField.threshold.rawValue))
        bytes.append(contentsOf: config.gain.toBytes(RFSetupField.gain.rawValue))
        bytes.append(contentsOf: config.frequency.toBytes(RFSetupField.frequency.rawValue))
        return finishPacket(&bytes)
    }
    
    public static func configurePilotSlots(_ slots: [IRCLapRFDevice.RFSetup]) -> [UInt8] {
        // Convert the 0-based slot indices to (1-MaxSlots)
        // This increment / decrement is hidden and managed inside this class
        var bytes = startPacket(.rfSetup)
        for (idx, slot) in slots.enumerated() {
            bytes.append(contentsOf: UInt8(idx + 1).toBytes(RFSetupField.slotIndex.rawValue))
            bytes.append(contentsOf: slot.enabled.toBytes(RFSetupField.enabled.rawValue))
            bytes.append(contentsOf: slot.channel.toBytes(RFSetupField.channel.rawValue))
            bytes.append(contentsOf: slot.band.toBytes(RFSetupField.band.rawValue))
            bytes.append(contentsOf: slot.threshold.toBytes(RFSetupField.threshold.rawValue))
            bytes.append(contentsOf: slot.gain.toBytes(RFSetupField.gain.rawValue))
            bytes.append(contentsOf: slot.frequency.toBytes(RFSetupField.frequency.rawValue))
        }
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
    
    // Request the current Real Time Clock Time on the device
    public static func requestRTCTime(_ device: IRCLapRFDevice) -> [UInt8] {
        var bytes = startPacket(.time)
        // Non-standard request format?
        bytes.append(TimeField.rtcTime.rawValue)
        bytes.append(0x00)
        device.rtcRequest = Date()
        return finishPacket(&bytes)
    }
    
    // Set the Real Time Clock Time on the device
    // This shuts down the device, so definitely not functional yet
    public static func resetRTCTime() -> [UInt8] {
         let msSince1970 = UInt64(Date().timeIntervalSince1970 * 1000)
        var bytes = startPacket(.time)
        bytes.append(contentsOf: msSince1970.toBytes(TimeField.rtcTime.rawValue))
        return finishPacket(&bytes)
    }
    
    public static func setGateState(_ state: IRCLapRFDevice.GateState) -> [UInt8] {
        var bytes = startPacket(.stateControl)
        bytes.append(contentsOf: state.rawValue.toBytes(StateControlField.gateState.rawValue))
        return finishPacket(&bytes)
    }
    
    public static func setMinLapTime(_ milliseconds: UInt32) -> [UInt8] {
        var bytes = startPacket(.settings)
        bytes.append(contentsOf: milliseconds.toBytes(SettingsField.minLapTime.rawValue))
        return finishPacket(&bytes)
    }
    
    // This function modifies the bytes array passed in
    // ... removing bytes when a complete record is found and processed
    // ... or any stray bytes in front of SOR (Start of Record) byte
    public static func processBytes(_ bytes: inout [UInt8], device: IRCLapRFDevice) {
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
                        if let record = decodeRecord(buffer, device: device) {
                            switch record.type {
                            case .rssi:
                                device.delegate?.rssiRangeUpdated(device, slot: record.slot ?? 0)
                            case .rfSetup:
                                device.delegate?.rfSetupRead(device, slot: record.slot ?? 0)
                            case .stateControl:
                                break
                            case .descriptor:
                                break
                            case .settings:
                                device.delegate?.settingsUpdated(device)
                            case .passing:
                                if let pr = device.passingRecords.last {
                                    device.delegate?.passingRecordRead(device, record: pr)
                                }
                            case .status:
                                device.delegate?.statusUpdated(device)
                            case .time:
                                device.delegate?.timeUpdated(device)
                            case .error:
                                break
                            }
                        }
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
    
    private static func decodeRecord(_ bytes: [UInt8], device: IRCLapRFDevice) -> (type: RecordType, slot: UInt8?)? {
        var packet = unescapeBytes(bytes)
        if packet.count < 8 {
            return nil
        }
        let sor = packet[0]
        if sor != SOR {
            return nil
        }
        let _ = UInt16(packet[1]) | UInt16(packet[2]) << 8
        let crc = UInt16(packet[3]) | UInt16(packet[4]) << 8
        packet[3] = 0
        packet[4] = 0
        let crc2 = IRCLapRFCRCCalc.instance.compute(packet)
        if crc != crc2 {
            return nil
        }
        let typeRaw = UInt16(packet[5]) | UInt16(packet[6]) << 8
        if let type = RecordType(rawValue: typeRaw) {
            packet.removeFirst(7)
            var passingRecord: IRCLapRFDevice.PassingRecord?
            if type == .passing {
                passingRecord = IRCLapRFDevice.PassingRecord()
            }
            var recordSlotIndex: UInt8?
            
            // all bytes in between SOR and EOR are grouped into individual records
            while packet.count > 3 {
                let signature = packet.removeFirst()
                let size = packet.removeFirst() // number of bytes
                if size > packet.count {
                    return nil // bad bad bad packet.
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
                        if let prTime = passingRecord?.rtcTimeSeconds {
                            passingRecord?.rtcTimeLocalSeconds = device.rtcTimeLocalSeconds + prTime
                        }
                        // complete the passing record
                        if let record = passingRecord {
                            device.passingRecords.append(record)
                            passingRecord = nil
                        }
                    case PassingField.passingNumber.rawValue:
                        passingRecord?.passingNumber = packet.readInteger()
                    case PassingField.decoderId.rawValue:
                        passingRecord?.decoderId = packet.readInteger()
                    case PassingField.peakHeight.rawValue:
                        passingRecord?.peakHeight = packet.readInteger()
                    case PassingField.flags.rawValue:
                        passingRecord?.flags = packet.readInteger()
                        
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                case .descriptor:
                    switch signature {
                    default:
                        // Record Type: 0xda08, Unknown Signature: 0x20, Size: 4
                        // Record Type: 0xda08, Unknown Signature: 0x21, Size: 1
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                case .rfSetup:
                    switch signature {
                    case RFSetupField.slotIndex.rawValue:
                        recordSlotIndex = max(0, packet.readInteger() - 1)// convert to 0-base
                    case RFSetupField.enabled.rawValue:
                        if let slot = recordSlotIndex {
                            device.rfSetupPerSlot[Int(slot)].enabled = packet.readInteger()
                        }
                    case RFSetupField.channel.rawValue:
                        if let slot = recordSlotIndex {
                            device.rfSetupPerSlot[Int(slot)].channel = packet.readInteger()
                        }
                    case RFSetupField.band.rawValue:
                        if let slot = recordSlotIndex {
                            device.rfSetupPerSlot[Int(slot)].band = packet.readInteger()
                        }
                    case RFSetupField.gain.rawValue:
                        if let slot = recordSlotIndex {
                            device.rfSetupPerSlot[Int(slot)].gain = packet.readInteger()
                        }
                    case RFSetupField.frequency.rawValue:
                        if let slot = recordSlotIndex {
                            device.rfSetupPerSlot[Int(slot)].frequency = packet.readInteger()
                        }
                    case RFSetupField.threshold.rawValue:
                        if let slot = recordSlotIndex {
                            device.rfSetupPerSlot[Int(slot)].threshold = packet.readFloat()
                        }
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                    
                case .rssi:
                    switch signature {
                    case RSSIField.slotIndex.rawValue:
                        recordSlotIndex = max(0, packet.readInteger() - 1) // convert to 0-base
                    case RSSIField.minRSSI.rawValue:
                        if let slot = recordSlotIndex {
                            device.rssiPerSlot[Int(slot)].minRssi = packet.readFloat()
                        }
                    case RSSIField.maxRSSI.rawValue:
                        if let slot = recordSlotIndex {
                            device.rssiPerSlot[Int(slot)].maxRssi = packet.readFloat()
                        }
                    case RSSIField.meanRSSI.rawValue:
                        if let slot = recordSlotIndex {
                            device.rssiPerSlot[Int(slot)].meanRssi = packet.readFloat()
                        }
                    case RSSIField.unknown1.rawValue:
                        let val: UInt32 = packet.readInteger()
                        // increments if the slot is enabled.
                        // no idea what triggers the increment.
                    case RSSIField.unknown2.rawValue:
                        let val: UInt32 = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                    
                case .settings:
                    switch signature {
                    case SettingsField.minLapTime.rawValue:
                        device.minLapTime = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                    
                case .status:
                    switch signature {
                    case StatusField.slotIndex.rawValue:
                        recordSlotIndex = max(0, packet.readInteger() - 1) // convert to 0-base
                    case StatusField.flags.rawValue:
                        device.statusFlags = packet.readInteger()
                    case StatusField.batteryVoltage.rawValue:
                        let voltagemV: UInt16 = packet.readInteger()
                        device.batteryVoltage = Float(voltagemV) / 1000.0
                    case StatusField.lastRSSI.rawValue:
                        if let slot = recordSlotIndex {
                            device.rssiPerSlot[Int(slot)].lastRssi = packet.readFloat()
                        }
                    case StatusField.gateState.rawValue:
                        device.gateState = IRCLapRFDevice.GateState(rawValue: packet.readInteger()) ?? .idle
                    case StatusField.detectionCount.rawValue:
                        device.detectionCount = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                case .stateControl:
                    switch signature {
                    case StateControlField.gateState.rawValue:
                        device.gateState = IRCLapRFDevice.GateState(rawValue: packet.readInteger()) ?? .idle
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                    
                case .time:
                    switch signature {
                    case TimeField.rtcTime.rawValue:
                        device.rtcTime = packet.readInteger()
                    case TimeField.timeRtcTime.rawValue:
                        device.timeRtcTime = packet.readInteger()
                    default:
                        print(String(format:"Record Type: 0x%02x, Unknown Signature: 0x%02x, Size: %d", type.rawValue, signature, size))
                    }
                    
                }
                packet.removeFirst(Int(size))
            }
            return (type, recordSlotIndex)
        } else {
            print("Unrecognized Type: \(typeRaw)")
        }
        return nil
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
