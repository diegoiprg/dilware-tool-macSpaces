import Foundation
import IOBluetooth

// 1. Obtener nombres reales y direcciones de dispositivos BT conectados
var btDevices: [(name: String, addr: String)] = []
for device in IOBluetoothDevice.pairedDevices() ?? [] {
    guard let d = device as? IOBluetoothDevice, d.isConnected() else { continue }
    let addr = (d.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":")
    btDevices.append((name: d.name ?? "Unknown", addr: addr))
}

// 2. Obtener batería de ioreg (por Product name → address mapping)
var ioregBattery: [String: Int] = [:]  // addr -> battery
let pipe = Pipe()
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
proc.arguments = ["-r", "-k", "BatteryPercent", "-l"]
proc.standardOutput = pipe
try? proc.run()
proc.waitUntilExit()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8) ?? ""

var currentAddr: String?
for line in output.components(separatedBy: "\n") {
    if let range = line.range(of: "\"DeviceAddress\" = \"") {
        let rest = line[range.upperBound...]
        if let end = rest.firstIndex(of: "\"") {
            currentAddr = String(rest[..<end]).uppercased().replacingOccurrences(of: "-", with: ":")
        }
    }
    if let range = line.range(of: "\"BatteryPercent\" = ") {
        let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        if let val = Int(rest), let addr = currentAddr {
            ioregBattery[addr] = val
        }
    }
}

// 3. Output: name|addr|battery (-1 si no disponible)
for bt in btDevices {
    let bat = ioregBattery[bt.addr] ?? -1
    print("\(bt.name)|\(bt.addr)|\(bat)")
}
