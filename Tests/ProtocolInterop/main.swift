import Foundation

// Send the app's real encoder output through the firmware's real C parser.
// This process is a host-only parser executable, with no USB code linked in.
var random: UInt32 = 0x52_48_50_4b
func byte() -> UInt8 { random = random &* 1664525 &+ 1013904223; return UInt8(truncatingIfNeeded: random >> 16) }
var scenes: [RGBLightingScene] = [.off, .hardwareTest]
for _ in 0..<126 {
    scenes.append(RGBLightingScene(leds: (0..<3).map { _ in
        LEDSetting(color: RGBColor(red: byte(), green: byte(), blue: byte()), brightness: byte(), enabled: byte() & 1 == 1)
    }))
}
var packets = scenes.enumerated().map { CustomLightingProtocol.encode(scene: $0.element, sequence: UInt8($0.offset)) }
for index in [0,1,2,3,4,5,6,7,9,22,23,24,25,26,27,28,29,30,31] {
    var invalid = packets.last!
    invalid[index] ^= 0xff
    packets.append(invalid)
}
let process = Process()
process.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
let input = Pipe(), output = Pipe()
process.standardInput = input
process.standardOutput = output
try process.run()
try input.fileHandleForWriting.write(contentsOf: Data(packets.flatMap { $0 }))
try input.fileHandleForWriting.close()
let result = [UInt8](output.fileHandleForReading.readDataToEndOfFile())
process.waitUntilExit()
precondition(process.terminationStatus == 0 && result.count == packets.count * 33, "Host parser did not return all frames")
for (index, scene) in scenes.enumerated() {
    let offset = index * 33
    precondition(result[offset] == 1, "Firmware rejected an app-generated frame")
    let reply = CustomLightingProtocol.decode(Array(result[(offset + 1)..<(offset + 33)]))
    precondition(reply?.sequence == UInt8(index) && reply?.matches(scene: scene) == true,
                 "Firmware readback disagrees with the app's scene")
}
let lastGood = Array(result[((scenes.count - 1) * 33 + 1)..<(scenes.count * 33)])
for index in scenes.count..<packets.count {
    let offset = index * 33
    precondition(result[offset] == 0, "Firmware accepted a malformed packet")
    precondition(Array(result[(offset + 1)..<(offset + 33)]) == lastGood, "Malformed packet partially changed the LEDs")
}
print("Passed \(packets.count) app-to-firmware protocol exchanges without hardware.")
