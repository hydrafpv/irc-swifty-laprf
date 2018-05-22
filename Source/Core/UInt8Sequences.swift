//
//  UInt8Sequences.swift
//

import Foundation

public extension Sequence where Iterator.Element == UInt8 {
    
    func hexString() -> String {
        return map { String(format:"0x%02x ", $0) }.joined()
    }
    
    func readInteger<T : FixedWidthInteger>() -> T {
        let map = self.map{T($0)}
        let bytes = T.bitWidth / 8
        var integer: T = 0
        for i in 0 ..< bytes {
            integer |= map[i] << (i * 8)
        }
        return integer
    }
    
    func readFloat() -> Float {
        let map = self.map{ $0 }
        var float: Float = 0
        memccpy(&float, map, 4, 4)
        return float
    }
    
    func readDouble() -> Double {
        let map = self.map{ $0 }
        var double: Double = 0
        memccpy(&double, map, 8, 8)
        return double
    }
    
}
