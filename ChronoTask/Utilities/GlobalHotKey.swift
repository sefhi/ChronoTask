import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
///
/// Uses Carbon's `RegisterEventHotKey` rather than `NSEvent.addGlobalMonitorForEvents`
/// because the latter needs Accessibility permission for key events — a prompt this
/// app has no other reason to make the user sit through. Carbon hot keys need nothing.
@MainActor
final class GlobalHotKey {

    struct Combo {
        let keyCode: UInt32
        let modifiers: UInt32
        let display: String

        /// ⌥⌘T — free in stock macOS and in the usual suspects (browsers, editors),
        /// and mnemonic for "timer".
        static let togglePanel = Combo(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(optionKey | cmdKey),
            display: "⌥⌘T"
        )
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    /// Registers the shortcut. Returns false if something else already owns it.
    @discardableResult
    func register(_ combo: Combo, action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action

        let signature: OSType = 0x4348_524E // 'CHRN'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                var receivedID = EventHotKeyID()
                GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &receivedID)
                guard receivedID.id == 1 else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                // The Carbon callback arrives on the main thread, but it is not a
                // Swift-concurrency context, so hop explicitly.
                DispatchQueue.main.async { hotKey.fire() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        guard installStatus == noErr else { return false }

        let status = RegisterEventHotKey(combo.keyCode,
                                         combo.modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            NSLog("[GlobalHotKey] could not register \(combo.display) (status \(status))")
            unregister()
            return false
        }
        return true
    }

    private func fire() {
        action?()
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
