import AppKit
import IOKit.hid

// Six reserved F-keys are consumed globally; ordinary keyboard input is untouched.
// HID enumeration supplies connection status only and never seizes the device.
final class KeypadInput {
    var onControl: ((ControlKey, Bool) -> Void)?
    var onStatus: ((String) -> Void)?
    var onDisconnect: (() -> Void)?
    var onUnknown: ((UInt32) -> Void)?
    private var manager: IOHIDManager?
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var down: [UInt16: ControlKey] = [:]
    private var orphanedUps: Set<UInt16> = []
    private var connected: Set<UInt> = []
    private var generation: UInt64 = 0

    func start() {
        stop()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                         place: .headInsertEventTap,
                                         options: .defaultTap,
                                         eventsOfInterest: mask,
                                         callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<KeypadInput>.fromOpaque(context).takeUnretainedValue()
                .receive(type: type, event: event)
        }, userInfo: context) else {
            onStatus?("Input access unavailable · allow Accessibility and Input Monitoring")
            return
        }
        eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            eventTap = nil
            onStatus?("Could not start keypad controls · reconnect to retry")
            return
        }
        eventSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onStatus?("Waiting for keypad · reserved F13–F18 controls active")

        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = m
        IOHIDManagerSetDeviceMatching(m, [
            kIOHIDVendorIDKey: 0x1189,
            kIOHIDProductIDKey: 0x8890,
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x06
        ] as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(m, { context, result, _, device in
            guard let context else { return }
            let owner = Unmanaged<KeypadInput>.fromOpaque(context).takeUnretainedValue()
            guard result == kIOReturnSuccess else {
                owner.onStatus?("Keypad detection unavailable (\(result)) · controls remain active")
                return
            }
            owner.connected.insert(UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque()))
            owner.onStatus?("Keypad connected")
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(m, { context, _, _, device in
            guard let context else { return }
            let owner = Unmanaged<KeypadInput>.fromOpaque(context).takeUnretainedValue()
            owner.connected.remove(UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque()))
            owner.invalidatePendingActions(notifyAsync: false)
            owner.onStatus?(owner.connected.isEmpty ? "Keypad disconnected · waiting" : "Keypad connected")
        }, context)
        // Matching/removal notifications need enumeration, not IOHIDManagerOpen.
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }

    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            invalidatePendingActions(notifyAsync: true)
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp {
            if let control = down.removeValue(forKey: code) {
                deliver(control, isDown: false)
                return nil
            }
            // Cancellation releases mapped actions immediately, but their eventual
            // physical key-up must still be consumed, regardless of modifier flags.
            if orphanedUps.remove(code) != nil { return nil }
            return Unmanaged.passUnretained(event)
        }
        // Repeats remain swallowed even if a modifier changed while held.
        if down[code] != nil { return nil }
        if orphanedUps.contains(code), event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
        let relevantFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        guard event.flags.intersection(relevantFlags).isEmpty,
              let control = ControlKey.fromTriggerKeyCode(code) else {
            return Unmanaged.passUnretained(event)
        }
        orphanedUps.remove(code)
        down[code] = control
        deliver(control, isDown: true)
        return nil
    }

    private func deliver(_ control: ControlKey, isDown: Bool) {
        let current = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == current, self.eventTap != nil else { return }
            self.onControl?(control, isDown)
        }
    }

    private func invalidatePendingActions(notifyAsync: Bool) {
        generation &+= 1
        orphanedUps.formUnion(down.keys)
        down.removeAll()
        if notifyAsync {
            let current = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == current else { return }
                self.onDisconnect?()
            }
        } else {
            onDisconnect?()
        }
    }

    func stop() {
        invalidatePendingActions(notifyAsync: false)
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let eventSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, CFRunLoopMode.commonModes)
            CFRunLoopSourceInvalidate(eventSource)
        }
        eventTap = nil
        eventSource = nil
        if let manager {
            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        manager = nil
        down.removeAll()
        orphanedUps.removeAll()
        connected.removeAll()
    }
    deinit { stop() }
}
