import AppKit
import Carbon

struct Shortcut {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    static let fallback = Shortcut(keyCode: 37, modifiers: UInt32(controlKey | optionKey), label: "⌃⌥L")

    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        var prefix = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); prefix += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); prefix += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); prefix += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); prefix += "⌘" }
        guard carbon != 0 else { return nil }
        let character = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let key = character == " " ? "空格" : character
        guard !key.isEmpty else { return nil }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: carbon, label: prefix + key)
    }
}

final class HotkeyManager {
    var onPressed: (() -> Void)?
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onPressed?() }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    deinit {
        if let hotkeyRef { UnregisterEventHotKey(hotkeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    @discardableResult func register(_ shortcut: Shortcut) -> Bool {
        if let hotkeyRef { UnregisterEventHotKey(hotkeyRef); self.hotkeyRef = nil }
        let identifier = EventHotKeyID(signature: 0x434C5044, id: 1) // CLPD
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier,
            GetApplicationEventTarget(), 0, &hotkeyRef) == noErr
    }
}

final class ShortcutRecorder: NSView {
    var shortcut: Shortcut?
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        let text = shortcut?.label ?? "点击这里，然后按快捷键"
        (text as NSString).draw(in: bounds.insetBy(dx: 12, dy: 8), withAttributes: [
            .font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.labelColor
        ])
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        if let captured = Shortcut.from(event) { shortcut = captured; needsDisplay = true }
        else { NSSound.beep() }
    }
}
