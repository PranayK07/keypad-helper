import AppKit
import IOKit
import IOKit.hid
import IOKit.usb

// This channel belongs only to our experimental firmware. Merely sharing the
// stock keypad's USB ID is never sufficient to send it a color command.
final class CustomLighting {
    var onConnection: ((CustomLightingConnection?) -> Void)?
    var onPresence: ((Bool) -> Void)?
    var onStatus: ((String) -> Void)?
    var onApplied: ((RGBLightingScene) -> Void)?
    var onFailure: (() -> Void)?

    private let queue = DispatchQueue(label: "KeypadCompanion.customLighting", qos: .utility)
    private let hid = CustomLightingHID()
    private var timer: DispatchSourceTimer?
    private var pending: DispatchWorkItem?
    private var wakeObserver: NSObjectProtocol?
    private var active = false
    private var connection: CustomLightingConnection?
    private var desired: RGBLightingScene?
    private var desiredIdentity: String?
    private var customPresent = false
    private var attempted: RGBLightingScene?
    private var applied: RGBLightingScene?
    private var sequence: UInt8 = 0
    private let lock = NSLock()
    private var revision: UInt64 = 0
    private var workerRevision: UInt64 = 0
    // Protected by lock, so an action queued from the UI cannot accidentally
    // authorize a newly connected keypad while its callback is still pending.
    private var currentIdentity: String?

    func start() {
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.queue.async { [weak self] in
                    guard let self, self.active else { return }
                    self.attempted = nil
                    self.applied = nil
                    // A desired scene exists only after a user-initiated test or
                    // the app's hardware verification gate has allowed it.
                    self.refresh()
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

    func apply(scene: RGBLightingScene, expectedConnectionIdentity: String, force: Bool = false) {
        guard let version = authorizeRevision(for: expectedConnectionIdentity) else { return }
        queue.async { [weak self] in
            guard let self, self.active else { return }
            guard self.isAuthorized(version, identity: expectedConnectionIdentity) else { return }
            self.workerRevision = version
            let scene = scene.normalized
            if self.desired != scene || force {
                self.attempted = nil
                if force { self.applied = nil }
            }
            self.desired = scene
            self.desiredIdentity = expectedConnectionIdentity
            self.pending?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.pending = nil
                self?.refresh()
            }
            self.pending = work
            self.queue.asyncAfter(deadline: .now() + .milliseconds(150), execute: work)
        }
    }

    // Revoking hardware verification cancels queued writes without changing LEDs.
    func clearDesired() {
        let version = advanceRevision()
        queue.async { [weak self] in
            guard let self else { return }
            self.workerRevision = version
            self.pending?.cancel()
            self.pending = nil
            self.desired = nil
            self.desiredIdentity = nil
            self.attempted = nil
            self.applied = nil
        }
    }

    func stop() {
        _ = advanceRevision()
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
            self.setConnection(nil)
            self.setPresence(false)
            self.hid.close()
        }
    }

    private func advanceRevision() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        revision &+= 1
        return revision
    }

    private func isCurrent(_ version: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return version == revision
    }

    private func authorizeRevision(for identity: String) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        guard CustomLightingAuthorization.permits(expected: identity, current: currentIdentity) else { return nil }
        revision &+= 1
        return revision
    }

    private func isAuthorized(_ version: UInt64, identity: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return version == revision && CustomLightingAuthorization.permits(expected: identity, current: currentIdentity)
    }

    private func deliver(_ body: @escaping (CustomLighting) -> Void) {
        let version = workerRevision
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCurrent(version) else { return }
            body(self)
        }
    }

    private func report(_ text: String) { deliver { $0.onStatus?(text) } }
    private func fail(_ text: String) {
        deliver { $0.onStatus?(text); $0.onFailure?() }
    }

    private func setConnection(_ value: CustomLightingConnection?) {
        guard value != connection else { return }
        connection = value
        lock.lock()
        currentIdentity = value?.identity
        revision &+= 1
        workerRevision = revision
        lock.unlock()
        // Never carry a previously approved scene to a new USB connection.
        pending?.cancel()
        pending = nil
        desired = nil
        desiredIdentity = nil
        attempted = nil
        applied = nil
        DispatchQueue.main.async { [weak self] in self?.onConnection?(value) }
    }

    private func setPresence(_ present: Bool) {
        guard present != customPresent else { return }
        customPresent = present
        // Presence and connection transitions are enqueued in worker order;
        // presence remains true if an identified firmware family fails a read.
        DispatchQueue.main.async { [weak self] in self?.onPresence?(present) }
    }

    private func refresh() {
        guard active else { return }
        do {
            let familyPresent = try hid.familyPresent()
            setPresence(familyPresent)
            let devices = try hid.devices()
            guard devices.count == 1, let device = devices.first else {
                setConnection(nil)
                if devices.count > 1 { report("Connect one RGB keypad to test its lighting") }
                else if familyPresent { report("Custom keypad connected · its RGB interface is unavailable or unsupported") }
                return
            }
            // Exact HID descriptors also establish presence if USB registry
            // naming differs between supported macOS driver implementations.
            setPresence(true)
            let identity = try hid.identity(of: device)
            let reply = try hid.read(from: device)
            let detected = CustomLightingConnection(identity: identity, firmwareVersion: 1)
            if detected != connection {
                setConnection(detected)
                report("RGB firmware detected · a visual lighting check is needed")
                return
            }
            guard let desired, let desiredIdentity,
                  CustomLightingAuthorization.permits(expected: desiredIdentity, current: detected.identity) else { return }
            if applied == desired, reply.matches(scene: desired) { return }
            // Firmware state changing unexpectedly (including a reset while the
            // USB service survives) permits one reapply of an approved scene.
            if applied == desired, !reply.matches(scene: desired) {
                applied = nil
                attempted = nil
            }
            guard attempted != desired, isAuthorized(workerRevision, identity: desiredIdentity) else { return }
            attempted = desired
            applied = nil
            sequence &+= 1
            let requestSequence = sequence
            report("Sending lighting…")
            let requestRevision = workerRevision
            let sent = try hid.write(scene: desired, sequence: requestSequence, to: device,
                shouldWrite: { [weak self] in
                    self?.isAuthorized(requestRevision, identity: desiredIdentity) == true
                })
            guard sent else { return }
            // Readback proves receipt of settings, never the physical LED result.
            let result = try hid.read(from: device)
            guard result.sequence == requestSequence, result.matches(scene: desired) else {
                throw CustomLightingHID.Failure("The keypad did not confirm these lighting settings")
            }
            guard isAuthorized(workerRevision, identity: desiredIdentity) else { return }
            applied = desired
            deliver { $0.onStatus?("Lighting settings received by keypad"); $0.onApplied?(desired) }
        } catch {
            // A failed read or write revokes the session: do not keep sending a
            // scene after firmware identity or connection health becomes unknown.
            setConnection(nil)
            fail("RGB lighting unavailable · \(error.localizedDescription)")
        }
    }
}

private final class CustomLightingHID {
    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
    private var manager: IOHIDManager?
    private var requestsBlocked = false

    func close() {
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        manager = nil
    }

    // Registry metadata only: this can recognize an unknown custom firmware
    // version without opening its HID interface or trying a legacy transaction.
    func familyPresent() throws -> Bool {
        let match = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        match[kUSBVendorID] = CustomFirmwareIdentity.vendorID
        match[kUSBProductID] = CustomFirmwareIdentity.productID
        var iterator: io_iterator_t = 0
        try Self.check(IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator), "find custom keypad")
        defer { IOObjectRelease(iterator) }
        var present = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func string(_ key: String) -> String {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? String ?? ""
            }
            if CustomFirmwareIdentity.belongsToCustomFamily(
                product: string(kUSBProductString), manufacturer: string(kUSBVendorString)) { present = true }
        }
        return present
    }

    func devices() throws -> [IOHIDDevice] {
        guard !requestsBlocked else { throw Failure("RGB communication stopped responding; reopen the app before retrying") }
        // A fresh manager gives each poll a current device inventory without
        // relying on notifications from an unscheduled manager/run loop.
        close()
        let value = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(value, [
            kIOHIDVendorIDKey: CustomFirmwareIdentity.vendorID,
            kIOHIDProductIDKey: CustomFirmwareIdentity.productID,
            kIOHIDManufacturerKey: CustomFirmwareIdentity.manufacturer,
            kIOHIDProductKey: CustomFirmwareIdentity.product,
            kIOHIDDeviceUsagePageKey: CustomFirmwareIdentity.usagePage,
            kIOHIDDeviceUsageKey: CustomFirmwareIdentity.usage
        ] as CFDictionary)
        try Self.check(IOHIDManagerOpen(value, IOOptionBits(kIOHIDOptionsTypeNone)), "open RGB configuration channel")
        manager = value
        guard let manager, let found = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return found.filter { device in
            CustomFirmwareIdentity.matches(
                vendorID: (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue ?? -1,
                productID: (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? -1,
                manufacturer: IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String ?? "",
                product: IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "",
                usagePage: IOHIDDeviceConformsTo(device, UInt32(CustomFirmwareIdentity.usagePage), UInt32(CustomFirmwareIdentity.usage)) ? CustomFirmwareIdentity.usagePage : -1,
                usage: CustomFirmwareIdentity.usage,
                featureReportSize: (IOHIDDeviceGetProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString) as? NSNumber)?.intValue ?? -1)
        }
    }

    func identity(of device: IOHIDDevice) throws -> String {
        var identifier: UInt64 = 0
        try Self.check(IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &identifier), "identify RGB connection")
        guard identifier != 0 else { throw Failure("RGB connection identity is unavailable") }
        // A registry ID intentionally changes on reconnect, requiring a fresh
        // visual verification even when firmware ships without a unique serial.
        return "KPHL-1-\(identifier)"
    }

    func read(from device: IOHIDDevice) throws -> CustomLightingReply {
        let bytes = try exchange(device: device, output: nil)
        guard let reply = CustomLightingProtocol.decode(bytes) else {
            throw Failure("This firmware's RGB protocol is not supported")
        }
        return reply
    }

    func write(scene: RGBLightingScene, sequence: UInt8, to device: IOHIDDevice,
               shouldWrite: () -> Bool) throws -> Bool {
        // Fresh read-only handshake immediately before each write. Every write is
        // the same validated, complete three-light scene; no other command exists.
        _ = try read(from: device)
        // A new profile or revoked verification may arrive during the handshake.
        // Drop the superseded write before submitting it to the USB device.
        guard shouldWrite() else { return false }
        _ = try exchange(device: device, output: CustomLightingProtocol.encode(scene: scene, sequence: sequence))
        return true
    }

    private static func check(_ result: IOReturn, _ action: String) throws {
        guard result == kIOReturnSuccess else {
            throw Failure("Could not \(action) (\(String(format: "0x%08x", UInt32(bitPattern: result))))")
        }
    }

    private final class ReportRequest {
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
        let length = UnsafeMutablePointer<CFIndex>.allocate(capacity: 1)
        var result: IOReturn?
        init(_ output: [UInt8]?) {
            bytes.initialize(repeating: 0, count: 32)
            length.initialize(to: 32)
            if let output { for index in 0..<32 { bytes[index] = output[index] } }
        }
        deinit { bytes.deallocate(); length.deallocate() }
    }

    private func exchange(device: IOHIDDevice, output: [UInt8]?) throws -> [UInt8] {
        guard !requestsBlocked else { throw Failure("RGB communication stopped responding; reopen the app before retrying") }
        guard output == nil || output?.count == 32 else { throw Failure("Invalid lighting packet length") }
        let request = ReportRequest(output)
        let loop = CFRunLoopGetCurrent()!
        let mode = CFRunLoopMode.defaultMode!
        // The feature-only collection is opened normally, never seized. The
        // typing interface and its input callbacks are not opened by this code.
        try Self.check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), "open RGB reports")
        IOHIDDeviceScheduleWithRunLoop(device, loop, mode.rawValue)
        defer {
            IOHIDDeviceUnscheduleFromRunLoop(device, loop, mode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        let callback: IOHIDReportCallback = { context, result, _, _, _, _, length in
            guard let context else { return }
            let request = Unmanaged<ReportRequest>.fromOpaque(context).takeRetainedValue()
            request.length.pointee = length
            request.result = result
        }
        // The completion owns this retain. If macOS fails to deliver even a
        // timeout callback, retaining the small request is safer than freeing a
        // buffer still owned by an outstanding kernel request. The hard timeout
        // below disables further requests for this transport's lifetime, bounding
        // that exceptional retention to one request per app session.
        let context = Unmanaged.passRetained(request).toOpaque()
        let submitted: IOReturn
        if output != nil {
            submitted = IOHIDDeviceSetReportWithCallback(device, kIOHIDReportTypeFeature, 0,
                request.bytes, 32, 1000, callback, context)
        } else {
            submitted = IOHIDDeviceGetReportWithCallback(device, kIOHIDReportTypeFeature, 0,
                request.bytes, request.length, 1000, callback, context)
        }
        if submitted != kIOReturnSuccess {
            Unmanaged<ReportRequest>.fromOpaque(context).release()
            try Self.check(submitted, "request RGB report")
        }
        // IOHID's documented request timeout is in milliseconds. Keep the request
        // storage alive until its completion/timeout callback, on this run loop.
        // No synchronous report API or main-thread wait is used.
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while request.result == nil, ProcessInfo.processInfo.systemUptime < deadline {
            CFRunLoopRunInMode(mode, 0.05, true)
        }
        guard let result = request.result else {
            requestsBlocked = true
            throw Failure("RGB report timed out; reopen the app before retrying")
        }
        try Self.check(result, "exchange RGB report")
        if output == nil, request.length.pointee != 32 { throw Failure("Unexpected RGB report length") }
        return Array(UnsafeBufferPointer(start: request.bytes, count: 32))
    }
}
