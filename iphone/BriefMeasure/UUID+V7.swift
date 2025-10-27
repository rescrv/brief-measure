import Foundation
import Security

extension UUID {
    static func v7String() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)

        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000.0)
        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        var randomBytes = [UInt8](repeating: 0, count: 10)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            for index in randomBytes.indices {
                randomBytes[index] = UInt8.random(in: 0...UInt8.max)
            }
        }

        bytes[6] = (randomBytes[0] & 0x0F) | 0x70
        bytes[7] = randomBytes[1]
        bytes[8] = (randomBytes[2] & 0x3F) | 0x80
        bytes[9] = randomBytes[3]
        bytes[10] = randomBytes[4]
        bytes[11] = randomBytes[5]
        bytes[12] = randomBytes[6]
        bytes[13] = randomBytes[7]
        bytes[14] = randomBytes[8]
        bytes[15] = randomBytes[9]

        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )

        return UUID(uuid: uuid).uuidString.lowercased()
    }
}
