import Foundation
import CryptoKit

/// MD5-based XOR encryption compatible with the Ruby implementation.
/// Uses uuencode → XOR with MD5 digest of salt → hex encoding.
enum Crypt {
    /// Encrypt a string using MD5-based XOR cipher.
    static func encrypt(_ str: String, salt: String) -> String? {
        let md5hex = md5Hex(salt)
        guard let packed = uuencode(str) else { return nil }

        var result: [UInt8] = []
        let packedBytes = Array(packed.utf8)
        for (i, byte) in packedBytes.enumerated() {
            let hexStart = (i * 4) % 32
            let hexSlice = extractHex(md5hex, start: hexStart, count: 4)
            let n = Int(UInt32(hexSlice, radix: 16) ?? 0)
            let charVal = Int(byte)
            let encrypted = (((charVal - 32 + n) % 64) + 64) % 64 + 32
            result.append(UInt8(encrypted))
        }

        return result.map { String(format: "%02x", $0) }.joined()
    }

    /// Decrypt a hex-encoded encrypted string.
    static func decrypt(_ hexStr: String, salt: String) -> String? {
        let md5hex = md5Hex(salt)
        guard let packedBytes = hexDecodeBytes(hexStr) else { return nil }

        var decrypted: [UInt8] = []
        for (i, byte) in packedBytes.enumerated() {
            let hexStart = (i * 4) % 32
            let hexSlice = extractHex(md5hex, start: hexStart, count: 4)
            let n = Int(UInt32(hexSlice, radix: 16) ?? 0)
            let charVal = Int(byte)
            let decryptedVal = (((charVal - 32 - n) % 64) + 64) % 64 + 32
            decrypted.append(UInt8(decryptedVal))
        }

        guard let decryptedStr = String(bytes: decrypted, encoding: .ascii) else { return nil }
        return uudecode(decryptedStr)
    }

    // MARK: - Helpers

    static func md5Hex(_ str: String) -> String {
        let data = Data(str.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func extractHex(_ hex: String, start: Int, count: Int) -> String {
        let s = hex.index(hex.startIndex, offsetBy: start)
        let e = hex.index(s, offsetBy: min(count, hex.count - start))
        return String(hex[s..<e])
    }

    /// Ruby's `[str].pack("u").chomp` equivalent
    private static func uuencode(_ str: String) -> String? {
        let data = Array(str.utf8)
        if data.isEmpty {
            // Ruby: [""].pack("u") => " \n", chomp => " "
            return String(Character(UnicodeScalar(32)!))
        }
        var result = ""

        var offset = 0
        while offset < data.count {
            let remaining = data.count - offset
            let lineLen = min(remaining, 45)
            result.append(Character(UnicodeScalar(lineLen + 32)!))

            var i = 0
            while i < lineLen {
                let b0 = Int(data[offset + i])
                let b1 = (offset + i + 1 < data.count) ? Int(data[offset + i + 1]) : 0
                let b2 = (offset + i + 2 < data.count) ? Int(data[offset + i + 2]) : 0

                result.append(Character(UnicodeScalar((b0 >> 2) + 32)!))
                result.append(Character(UnicodeScalar((((b0 & 0x03) << 4) | (b1 >> 4)) + 32)!))
                result.append(Character(UnicodeScalar((((b1 & 0x0F) << 2) | (b2 >> 6)) + 32)!))
                result.append(Character(UnicodeScalar((b2 & 0x3F) + 32)!))

                i += 3
            }

            offset += lineLen
            if offset < data.count {
                result.append("\n")
            }
        }

        return result
    }

    /// Ruby's `str.unpack("u")[0]` equivalent
    private static func uudecode(_ str: String) -> String? {
        var bytes: [UInt8] = []

        for line in str.split(separator: "\n", omittingEmptySubsequences: false) {
            let chars = Array(line.utf8)
            guard !chars.isEmpty else { continue }
            let lineLen = Int(chars[0]) - 32
            if lineLen <= 0 { continue }

            var i = 1
            var decoded = 0
            while i + 3 < chars.count, decoded < lineLen {
                let c0 = (Int(chars[i]) - 32) & 0x3F
                let c1 = (Int(chars[i+1]) - 32) & 0x3F
                let c2 = (Int(chars[i+2]) - 32) & 0x3F
                let c3 = (Int(chars[i+3]) - 32) & 0x3F

                if decoded < lineLen {
                    bytes.append(UInt8((c0 << 2) | (c1 >> 4)))
                    decoded += 1
                }
                if decoded < lineLen {
                    bytes.append(UInt8(((c1 & 0x0F) << 4) | (c2 >> 2)))
                    decoded += 1
                }
                if decoded < lineLen {
                    bytes.append(UInt8(((c2 & 0x03) << 6) | c3))
                    decoded += 1
                }
                i += 4
            }
        }

        return String(bytes: bytes, encoding: .utf8)
    }

    /// Decode hex string to byte array
    private static func hexDecodeBytes(_ hex: String) -> [UInt8]? {
        var result: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            guard let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) else { break }
            let hexByte = hex[index..<nextIndex]
            guard let byte = UInt8(hexByte, radix: 16) else { return nil }
            result.append(byte)
            index = nextIndex
        }
        return result
    }
}
