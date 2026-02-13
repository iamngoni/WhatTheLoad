import Foundation
import IOKit

// SMC key structure
struct SMCKey {
    let code: UInt32

    init(_ string: String) {
        var code: UInt32 = 0
        for char in string.utf8 {
            code = code << 8 | UInt32(char)
        }
        self.code = code
    }
}

// SMC data types
enum SMCDataType: UInt32 {
    case sp78 = 0x73703738  // Temperature (floating point)
    case fpe2 = 0x66706532  // Fan speed
    case ui8  = 0x75693820  // Unsigned 8-bit
    case ui16 = 0x75693136  // Unsigned 16-bit
    case ui32 = 0x75693332  // Unsigned 32-bit
}

// SMC commands
enum SMCCommand: UInt8 {
    case readKey = 5
    case writeKey = 6
    case getKeyInfo = 9
}

// SMC structures
struct SMCKeyData {
    var key: UInt32 = 0
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0)
    var pLimitData: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var keyInfo: SMCKeyInfoData = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

class SMCReader {
    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)

        guard result == kIOReturnSuccess else { return nil }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readTemperature(key: String) -> Double? {
        guard let value = readKey(key) else { return nil }

        // Decode sp78 format: signed fixed-point (8.8)
        let intValue = Int16(bigEndian: value.withUnsafeBytes { $0.load(as: Int16.self) })
        return Double(intValue) / 256.0
    }

    private func readKey(_ keyString: String) -> Data? {
        let key = SMCKey(keyString)

        var inputData = SMCKeyData()
        var outputData = SMCKeyData()

        inputData.key = key.code
        inputData.data8 = SMCCommand.readKey.rawValue

        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = inputSize

        let result = withUnsafePointer(to: &inputData) { inputPtr in
            withUnsafeMutablePointer(to: &outputData) { outputPtr in
                IOConnectCallStructMethod(
                    connection,
                    2,  // SMC selector
                    inputPtr,
                    inputSize,
                    outputPtr,
                    &outputSize
                )
            }
        }

        guard result == kIOReturnSuccess, outputData.result == 0 else { return nil }

        // Extract bytes
        return withUnsafeBytes(of: outputData.bytes) { buffer in
            Data(buffer.prefix(Int(outputData.keyInfo.dataSize)))
        }
    }

    // Common temperature sensors
    static let cpuTemperatureKeys = ["TC0P", "TC0D", "TC0E", "TC0F"]
    static let batteryTemperatureKeys = ["TB0T", "TB1T", "TB2T"]

    func getCPUTemperature() -> Double? {
        for key in Self.cpuTemperatureKeys {
            if let temp = readTemperature(key: key) {
                return temp
            }
        }
        return nil
    }

    func getBatteryTemperature() -> Double? {
        for key in Self.batteryTemperatureKeys {
            if let temp = readTemperature(key: key) {
                return temp
            }
        }
        return nil
    }
}
