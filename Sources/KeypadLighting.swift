import AppKit
import IOKit
import IOKit.usb

// Only the three documented CH57x-2 effects are sent. The known LED transaction
// selects layer 1, matching this app's one-layer trigger configuration. No key
// bindings, firmware operations, or guessed RGB fields are written here.
final class KeypadLighting {
    var onStatus: ((String) -> Void)?
    private let queue = DispatchQueue(label: "KeypadCompanion.lighting", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var pending: DispatchWorkItem?
    private var desired: LEDMode?
    private var lastApplied: (device: UInt64, mode: Int)?
    private var active = false
    private var lastStatus = ""
    private var lastStatusRevision: UInt64 = 0
    private var wakeObserver: NSObjectProtocol?
    private let revisionLock = NSLock()
    private var latestRevision: UInt64 = 0
    private var workerRevision: UInt64 = 0
    // A failed write is retried by explicit Apply, a changed selection, or reconnect;
    // the connection poll must never continuously rewrite the device's flash.
    private var attempted: (device: UInt64, mode: Int)?

    func start() {
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                let revision = self.nextRevision()
                self.queue.async { [weak self] in
                    guard let self, self.active else { return }
                    self.workerRevision = revision
                    self.lastApplied = nil
                    self.attempted = nil
                    self.scheduleApply()
                }
            }
        }
        queue.async { [weak self] in
            guard let self, !self.active else { return }
            self.active = true
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(500))
            timer.setEventHandler { [weak self] in
                guard let self, self.pending == nil else { return }
                self.refresh()
            }
            self.timer = timer
            timer.resume()
        }
    }

    func apply(mode: LEDMode, force: Bool = false) {
        let revision = nextRevision()
        queue.async { [weak self] in
            guard let self else { return }
            self.workerRevision = revision
            if self.desired != mode || force {
                self.attempted = nil
                if force { self.lastApplied = nil }
            }
            self.desired = mode
            self.scheduleApply()
        }
    }

    func stop() {
        _ = nextRevision()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        queue.async { [weak self] in
            guard let self else { return }
            self.active = false
            self.timer?.cancel()
            self.timer = nil
            self.pending?.cancel()
            self.pending = nil
            self.lastApplied = nil
            self.attempted = nil
        }
    }

    private func scheduleApply() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.refresh()
        }
        pending = work
        queue.asyncAfter(deadline: .now() + .milliseconds(300), execute: work)
    }

    private func report(_ status: String) {
        guard status != lastStatus || workerRevision != lastStatusRevision else { return }
        lastStatus = status
        lastStatusRevision = workerRevision
        let revision = workerRevision
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.revisionLock.lock()
            let current = self.latestRevision
            self.revisionLock.unlock()
            guard revision == current else { return }
            self.onStatus?(status)
        }
    }

    private func nextRevision() -> UInt64 {
        revisionLock.lock()
        defer { revisionLock.unlock() }
        latestRevision &+= 1
        return latestRevision
    }

    private func refresh() {
        guard active, let desired else { return }
        do {
            let services = try LightingUSB.devices()
            defer { services.forEach { IOObjectRelease($0) } }
            guard services.count == 1, let service = services.first else {
                lastApplied = nil
                attempted = nil
                report(services.isEmpty ? "Waiting for keypad · your lighting choice is saved" : "Connect one supported keypad to change its lighting")
                return
            }
            var deviceID: UInt64 = 0
            try LightingUSB.check(IORegistryEntryGetRegistryEntryID(service, &deviceID), "identify keypad")
            let mode = desired.rawValue
            if lastApplied?.device == deviceID, lastApplied?.mode == mode {
                report("\(desired.title) sent to keypad")
                return
            }
            if attempted?.device == deviceID, attempted?.mode == mode { report(lastStatus); return }
            attempted = (deviceID, mode)
            report("Applying lighting…")
            lastApplied = nil
            try LightingUSB.write(mode: mode, to: service)
            lastApplied = (deviceID, mode)
            report("\(desired.title) sent to keypad")
        } catch {
            report("Lighting could not be applied · \(error.localizedDescription). Choose Reapply effect to retry.")
        }
    }
}

private enum LightingUSB {
    typealias Device = UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>
    typealias Interface = UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>?>
    // IOUSBLib UUID macros are not imported into Swift; these are their SDK values.
    static let pluginID = uuid("C244E858-109C-11D4-91D4-0050E4C6426F")
    static let deviceClientID = uuid("9DC7B780-9EC0-11D4-A54F-000A27052861")
    static let deviceID = uuid("5C8187D0-9EF3-11D4-8B45-000A27052861")
    static let interfaceClientID = uuid("2D9786C6-9EF3-11D4-AD51-000A27052861")
    static let interfaceID = uuid("73C97AE8-9EF3-11D4-B1D0-000A27052861")
    static func uuid(_ string: String) -> CFUUID { CFUUIDCreateFromString(nil, string as CFString)! }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func check(_ result: IOReturn, _ action: String) throws {
        guard result == kIOReturnSuccess else {
            throw Failure(message: "could not \(action) (\(String(format: "0x%08x", UInt32(bitPattern: result))))")
        }
    }

    static func devices() throws -> [io_service_t] {
        let match = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        match[kUSBVendorID] = 0x1189
        match[kUSBProductID] = 0x8890
        var iterator: io_iterator_t = 0
        try check(IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator), "find keypad")
        defer { IOObjectRelease(iterator) }
        var result: [io_service_t] = []
        while case let service = IOIteratorNext(iterator), service != 0 { result.append(service) }
        return result
    }

    static func query<T>(_ service: io_service_t, client: CFUUID, interface: CFUUID,
                         as type: T.Type) throws -> UnsafeMutablePointer<UnsafeMutablePointer<T>?> {
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        try check(IOCreatePlugInInterfaceForService(service, client, pluginID, &plugin, &score), "access USB interface")
        guard let plugin else { throw Failure(message: "USB interface unavailable") }
        defer { IODestroyPlugInInterface(plugin) }
        var result: UnsafeMutablePointer<UnsafeMutablePointer<T>?>?
        let status = withUnsafeMutablePointer(to: &result) { pointer in
            plugin.pointee!.pointee.QueryInterface(UnsafeMutableRawPointer(plugin), CFUUIDGetUUIDBytes(interface),
                UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: Optional<UnsafeMutableRawPointer>.self))
        }
        guard status == 0, let result else { throw Failure(message: "USB interface unavailable") }
        return result
    }

    static func write(mode: Int, to service: io_service_t) throws {
        guard (0...2).contains(mode) else { throw Failure(message: "unsupported lighting mode") }
        let device = try query(service, client: deviceClientID, interface: deviceID, as: IOUSBDeviceInterface.self)
        defer { _ = device.pointee!.pointee.Release(device) }
        var request = IOUSBFindInterfaceRequest(bInterfaceClass: UInt16(kIOUSBFindInterfaceDontCare),
            bInterfaceSubClass: UInt16(kIOUSBFindInterfaceDontCare), bInterfaceProtocol: UInt16(kIOUSBFindInterfaceDontCare),
            bAlternateSetting: UInt16(kIOUSBFindInterfaceDontCare))
        var iterator: io_iterator_t = 0
        try check(device.pointee!.pointee.CreateInterfaceIterator(device, &request, &iterator), "find lighting interface")
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let interface = try query(service, client: interfaceClientID, interface: interfaceID, as: IOUSBInterfaceInterface.self)
            defer { _ = interface.pointee!.pointee.Release(interface) }
            var number: UInt8 = 255
            try check(interface.pointee!.pointee.GetInterfaceNumber(interface, &number), "identify lighting interface")
            guard number == 1 else { continue }
            // Configuration interface only. Never open/seize the typing interfaces.
            try check(interface.pointee!.pointee.USBInterfaceOpen(interface), "open lighting interface")
            defer { _ = interface.pointee!.pointee.USBInterfaceClose(interface) }
            var count: UInt8 = 0
            try check(interface.pointee!.pointee.GetNumEndpoints(interface, &count), "find lighting endpoint")
            guard count > 0 else { throw Failure(message: "lighting endpoint unavailable") }
            for pipe in UInt8(1)...count {
                var direction: UInt8 = 0, endpoint: UInt8 = 0, transfer: UInt8 = 0, interval: UInt8 = 0
                var size: UInt16 = 0
                try check(interface.pointee!.pointee.GetPipeProperties(interface, pipe, &direction, &endpoint,
                    &transfer, &size, &interval), "inspect lighting endpoint")
                guard direction == 0, endpoint == 2, transfer == 3, size == 64 else { continue }
                // Same four 64-byte interrupt transfers as ch57x-keyboard-tool 1.8.0:
                // https://github.com/kriomant/ch57x-keyboard-tool/blob/master/src/keyboard/k8890.rs
                // Its main.rs supplies the leading all-zero initialization report.
                for prefix: [UInt8] in [[], [3, 0xa1, 1], [3, 0xb0, 0x18, UInt8(mode)], [3, 0xaa, 0xa1]] {
                    var packet = prefix + Array(repeating: UInt8(0), count: 64 - prefix.count)
                    try send(&packet, interface: interface, pipe: pipe)
                }
                return
            }
            throw Failure(message: "this keypad's lighting endpoint is not supported")
        }
        throw Failure(message: "lighting interface unavailable")
    }

    private final class Deadline {
        let lock = NSLock()
        var completed = false
        var expired = false
    }
    private static func send(_ packet: inout [UInt8], interface: Interface, pipe: UInt8) throws {
        // WritePipe supports interrupt OUT but has no timeout argument. Abort the
        // request after one second; the lock keeps the interface alive until an
        // in-progress abort finishes, before the caller closes/releases it.
        let deadline = Deadline()
        let watchdog = DispatchWorkItem {
            deadline.lock.lock()
            defer { deadline.lock.unlock() }
            guard !deadline.completed else { return }
            deadline.expired = true
            _ = interface.pointee!.pointee.AbortPipe(interface, pipe)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: watchdog)
        let result = packet.withUnsafeMutableBytes {
            interface.pointee!.pointee.WritePipe(interface, pipe, $0.baseAddress, UInt32($0.count))
        }
        deadline.lock.lock()
        deadline.completed = true
        let expired = deadline.expired
        deadline.lock.unlock()
        watchdog.cancel()
        try check(expired ? kIOReturnTimeout : result, "send lighting setting")
    }
}
