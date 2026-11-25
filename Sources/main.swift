// Moveable — Ctrl + Option + Shift + 방향키로 현재 선택된(포커스된) 창을 부드럽게 이동시키는 메뉴바 앱.

import AppKit
import ApplicationServices
import ServiceManagement

// MARK: - 상태 로그 (~/Library/Logs/Moveable.log)

func statusLog(_ msg: String) {
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Moveable.log")
    let line = "\(Date()) \(msg)\n"
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - 설정

enum Prefs {
    static let speedKey = "speedPixelsPerSecond"
    static let speedOptions: [(String, Double)] = [
        ("느리게 (400 px/s)", 400),
        ("보통 (800 px/s)", 800),
        ("빠르게 (1400 px/s)", 1400),
        ("아주 빠르게 (2200 px/s)", 2200),
    ]
    static var speed: Double {
        get {
            let v = UserDefaults.standard.double(forKey: speedKey)
            return v > 0 ? v : 800
        }
        set { UserDefaults.standard.set(newValue, forKey: speedKey) }
    }
}

// MARK: - 키 코드

enum ArrowKey: Int64 {
    case left = 123, right = 124, down = 125, up = 126

    var vector: CGVector {
        switch self {
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        case .up: return CGVector(dx: 0, dy: -1)    // AX 좌표계는 위쪽이 y 감소
        case .down: return CGVector(dx: 0, dy: 1)
        }
    }
}

let requiredFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift]
let relevantFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]

// MARK: - 창 이동 엔진

final class WindowMover {
    private var held = Set<ArrowKey>()
    private var timer: Timer?
    private var window: AXUIElement?
    private var appElement: AXUIElement?
    private var restoreEnhancedUI = false
    private var position = CGPoint.zero
    private var lastTick: CFTimeInterval = 0

    var isMoving: Bool { timer != nil }

    func press(_ key: ArrowKey) {
        held.insert(key)
        if timer == nil { start() }
    }

    func release(_ key: ArrowKey) {
        held.remove(key)
        if held.isEmpty { stop() }
    }

    func releaseAll() {
        held.removeAll()
        stop()
    }

    private func start() {
        guard let (app, win) = Self.focusedWindow(),
              let pos = Self.position(of: win) else {
            held.removeAll()
            return
        }
        appElement = app
        window = win
        position = pos

        // Chrome/Electron 등은 AXEnhancedUserInterface 가 켜져 있으면 창 이동이 애니메이션되어 버벅인다.
        // 이동하는 동안만 잠시 꺼둔다.
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &value) == .success,
           let enabled = value as? Bool, enabled {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
            restoreEnhancedUI = true
        }

        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        if restoreEnhancedUI, let app = appElement {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        restoreEnhancedUI = false
        window = nil
        appElement = nil
    }

    private func tick() {
        guard let win = window else { return stop() }
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.05)   // 한 프레임이 밀려도 크게 튀지 않도록
        lastTick = now

        var dx: CGFloat = 0, dy: CGFloat = 0
        for k in held { dx += k.vector.dx; dy += k.vector.dy }
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { return }       // 좌+우 동시 등 상쇄
        let step = CGFloat(Prefs.speed * dt) / len
        position.x += dx * step
        position.y += dy * step

        var p = CGPoint(x: position.x.rounded(), y: position.y.rounded())
        if let v = AXValueCreate(.cgPoint, &p) {
            if AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, v) != .success {
                releaseAll()
            }
        }
    }

    private static func focusedWindow() -> (AXUIElement, AXUIElement)? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() {
            return (app, v as! AXUIElement)
        }
        if AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &value) == .success,
           let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() {
            return (app, v as! AXUIElement)
        }
        return nil
    }

    private static func position(of win: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero
        AXValueGetValue(v as! AXValue, .cgPoint, &p)
        return p
    }
}

// MARK: - 키보드 이벤트 탭

final class HotkeyTap {
    let mover: WindowMover
    private var tap: CFMachPort?

    init(mover: WindowMover) { self.mover = mover }

    var isInstalled: Bool { tap != nil }

    func install() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.keyUp.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else { return false }

        tap = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            mover.releaseAll()
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            // 수정키 중 하나라도 떼면 즉시 멈춤
            if mover.isMoving && !event.flags.contains(requiredFlags) {
                mover.releaseAll()
            }
            return Unmanaged.passUnretained(event)

        case .keyDown, .keyUp:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            guard let key = ArrowKey(rawValue: code) else { return Unmanaged.passUnretained(event) }
            let flags = event.flags.intersection(relevantFlags)

            if type == .keyDown {
                guard flags == requiredFlags else { return Unmanaged.passUnretained(event) }
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    mover.press(key)
                }
                return nil  // 단축키는 앱으로 전달하지 않음
            } else {
                if mover.isMoving {
                    mover.release(key)
                    return nil
                }
                return Unmanaged.passUnretained(event)
            }

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

// MARK: - 앱 / 메뉴바

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mover = WindowMover()
    private lazy var hotkeys = HotkeyTap(mover: mover)
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right",
                                   accessibilityDescription: "Moveable")
        }
        buildMenu()
        ensurePermissionAndInstall(prompt: true)
    }

    private func buildMenu() {
        let menu = NSMenu()

        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        let hint = NSMenuItem(title: "⌃⌥⇧ + 방향키: 선택된 창 이동", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let speedHeader = NSMenuItem(title: "이동 속도", action: nil, keyEquivalent: "")
        speedHeader.isEnabled = false
        menu.addItem(speedHeader)
        for (title, value) in Prefs.speedOptions {
            let item = NSMenuItem(title: title, action: #selector(selectSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.indentationLevel = 1
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let login = NSMenuItem(title: "로그인 시 자동 실행", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.tag = 100
        menu.addItem(login)

        let ax = NSMenuItem(title: "손쉬운 사용 설정 열기…", action: #selector(openAccessibility), keyEquivalent: "")
        ax.target = self
        menu.addItem(ax)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Moveable 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
        refreshMenu()
    }

    fileprivate func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        statusLine.title = hotkeys.isInstalled ? "● 동작 중" : "○ 손쉬운 사용 권한 필요"
        for item in menu.items {
            if let v = item.representedObject as? Double {
                item.state = (v == Prefs.speed) ? .on : .off
            }
            if item.tag == 100 {
                item.state = SMAppService.mainApp.status == .enabled ? .on : .off
            }
        }
    }

    private func ensurePermissionAndInstall(prompt: Bool) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts), hotkeys.install() {
            statusLog("hotkey tap installed (permission OK)")
            permissionTimer?.invalidate()
            permissionTimer = nil
            refreshMenu()
            return
        }
        if prompt { statusLog("waiting for Accessibility permission") }
        refreshMenu()
        // 권한이 허용될 때까지 1초마다 다시 확인
        if permissionTimer == nil {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.ensurePermissionAndInstall(prompt: false)
            }
        }
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) {
        if let v = sender.representedObject as? Double { Prefs.speed = v }
        refreshMenu()
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "로그인 항목 설정 실패"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { refreshMenu() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
