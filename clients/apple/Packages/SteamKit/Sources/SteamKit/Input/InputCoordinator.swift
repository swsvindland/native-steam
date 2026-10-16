import GameController
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
import UIKit.UIGestureRecognizerSubclass
#endif

/// Wires every input source into the `FocusEngine` / `AppModel`:
/// game controllers (GameController framework), arrow keys (NSEvent on macOS,
/// GCKeyboard on iPadOS) and pointer/touch detection for "last input" tracking.
@MainActor
public final class InputCoordinator {
    let model: AppModel
    let engine: FocusEngine
    private var started = false
    private var repeatTask: Task<Void, Never>?
    private var heldDirection: MoveDirection?
    private var stickDirection: MoveDirection?
    private var observers: [NSObjectProtocol] = []
    #if os(macOS)
    private var eventMonitor: Any?
    #endif

    public init(model: AppModel, engine: FocusEngine) {
        self.model = model
        self.engine = engine
    }

    public func start() {
        guard !started else { return }
        started = true

        if model.launch.forceGamepad {
            engine.input = .gamepad
            engine.gamepadConnected = true
            engine.requestDefaultFocus()
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshControllers() }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshControllers() }
        })
        refreshControllers()

        #if os(macOS)
        installKeyMonitor()
        #else
        observers.append(center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.configureKeyboard() }
        })
        configureKeyboard()
        #endif
    }

    // MARK: - Game controllers

    private func refreshControllers() {
        let pads = GCController.controllers().filter { $0.extendedGamepad != nil }
        engine.gamepadConnected = !pads.isEmpty || model.launch.forceGamepad
        if FocusEngine.debug {
            let names = GCController.controllers().map { "\($0.vendorName ?? "?") (\($0.productCategory))" }
            FileHandle.standardError.write("[input] controllers: \(names)\n".data(using: .utf8)!)
        }
        for controller in pads { configure(controller) }
    }

    private func configure(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        controller.handlerQueue = .main

        pad.dpad.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.directional(x: x, y: y, threshold: 0.5, fromStick: false) }
        }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.directional(x: x, y: y, threshold: 0.6, fromStick: true) }
        }
        pad.buttonA.pressedChangedHandler = button { $0.engine.activate() }
        pad.buttonB.pressedChangedHandler = button { $0.back() }
        pad.buttonY.pressedChangedHandler = button { $0.model.requestSearch() }
        pad.buttonX.pressedChangedHandler = button { $0.engine.secondary() }
        pad.leftShoulder.pressedChangedHandler = button { $0.switchTab(-1) }
        pad.rightShoulder.pressedChangedHandler = button { $0.switchTab(1) }
        pad.leftTrigger.pressedChangedHandler = button { $0.model.pageSection(by: -1) }
        pad.rightTrigger.pressedChangedHandler = button { $0.model.pageSection(by: 1) }
    }

    private func button(_ action: @escaping @MainActor (InputCoordinator) -> Void) -> GCControllerButtonValueChangedHandler {
        { [weak self] _, _, pressed in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.engine.input = .gamepad
                if pressed { action(self) }
            }
        }
    }

    private func directional(x: Float, y: Float, threshold: Float, fromStick: Bool) {
        var dir: MoveDirection?
        if abs(x) >= threshold || abs(y) >= threshold {
            dir = abs(x) > abs(y) ? (x > 0 ? .right : .left) : (y > 0 ? .up : .down)
        }
        if fromStick {
            guard dir != stickDirection else { return }
            stickDirection = dir
        } else {
            guard dir != heldDirection else { return }
            heldDirection = dir
        }
        repeatTask?.cancel()
        guard let dir else { return }
        engine.input = .gamepad
        engine.move(dir)
        repeatTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            while !Task.isCancelled {
                self?.engine.move(dir)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    // MARK: - Shared actions

    func back() {
        if !model.pop() {
            engine.focusTabBar?()
        }
    }

    func switchTab(_ delta: Int) {
        if delta > 0 { model.nextTab() } else { model.previousTab() }
        engine.requestDefaultFocus()
    }

    // MARK: - Keyboard

    #if os(macOS)
    private func installKeyMonitor() {
        NSApp.windows.forEach { $0.acceptsMouseMovedEvents = true }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .mouseMoved]
        ) { [weak self] event in
            let box = UncheckedEvent(event: event)
            guard let self else { return event }
            return MainActor.assumeIsolated { UncheckedEvent(event: self.handle(box.event!)) }.event
        }
    }

    /// NSEvent isn't Sendable; local monitors run on the main thread, so this is safe.
    private struct UncheckedEvent: @unchecked Sendable {
        let event: NSEvent?
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .keyDown:
            return handleKey(event)
        case .scrollWheel:
            // Count real gestures / wheel ticks, not trailing momentum.
            if event.phase == .began || (event.phase == [] && event.momentumPhase == []) {
                if engine.input != .pointer { engine.input = .pointer }
            }
            return event
        default:
            if engine.input != .pointer { engine.input = .pointer }
            return event
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty else { return event }
        let editing = (event.window?.firstResponder is NSText)
        if editing {
            if event.keyCode == 53 { // Esc leaves the text field
                event.window?.makeFirstResponder(nil)
                engine.textInputActive = false
                return nil
            }
            return event
        }
        switch event.keyCode {
        case 123: arrow(.left); return nil
        case 124: arrow(.right); return nil
        case 125: arrow(.down); return nil
        case 126: arrow(.up); return nil
        case 36, 76, 49: // Return, Enter, Space
            engine.input = .keyboard
            if engine.focusedID != nil {
                engine.activate()
                return nil
            }
            return event
        case 53, 51: // Esc, Delete
            engine.input = .keyboard
            back()
            return nil
        case 48: // Tab — let SwiftUI move focus (mirrored into the engine), show the ring.
            engine.input = .keyboard
            engine.acceptsSystemFocusUntil = Date().addingTimeInterval(0.5)
            return event
        default:
            return event
        }
    }

    private func arrow(_ dir: MoveDirection) {
        let wasShowing = engine.showsFocus
        engine.input = .keyboard
        if wasShowing || engine.focusedID == nil {
            engine.move(dir)
        }
    }
    #else
    private func configureKeyboard() {
        guard let keyboard = GCKeyboard.coalesced?.keyboardInput else { return }
        keyboard.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            MainActor.assumeIsolated { self?.handleKey(keyCode, pressed: pressed) }
        }
    }

    private func handleKey(_ key: GCKeyCode, pressed: Bool) {
        guard pressed, !engine.textInputActive else { return }
        if let modifiers = GCKeyboard.coalesced?.keyboardInput,
           modifiers.button(forKeyCode: .leftGUI)?.isPressed == true || modifiers.button(forKeyCode: .rightGUI)?.isPressed == true {
            return
        }
        switch key {
        case .upArrow: arrow(.up)
        case .downArrow: arrow(.down)
        case .leftArrow: arrow(.left)
        case .rightArrow: arrow(.right)
        case .returnOrEnter, .keypadEnter, .spacebar:
            engine.input = .keyboard
            engine.activate()
        case .escape, .deleteOrBackspace:
            engine.input = .keyboard
            back()
        default:
            break
        }
    }

    private func arrow(_ dir: MoveDirection) {
        let wasShowing = engine.showsFocus
        engine.input = .keyboard
        if wasShowing || engine.focusedID == nil { engine.move(dir) }
    }

    /// Called by the touch observer installed on the key window.
    func touchBegan(_ type: UITouch.TouchType) {
        let kind: InputKind = type == .indirectPointer ? .pointer : .touch
        if engine.input != kind { engine.input = kind }
    }
    #endif
}

#if os(iOS)
/// Observes every touch in the window without interfering, to track "last input = touch".
final class TouchObserverGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTouch: ((UITouch.TouchType) -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first { onTouch?(touch.type) }
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

struct TouchObserverInstaller: UIViewRepresentable {
    let coordinator: InputCoordinator

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.coordinator = coordinator
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        weak var coordinator: InputCoordinator?
        private var installed = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !installed, let window else { return }
            installed = true
            let gesture = TouchObserverGesture(target: nil, action: nil)
            gesture.onTouch = { [weak self] type in self?.coordinator?.touchBegan(type) }
            window.addGestureRecognizer(gesture)
        }
    }
}
#endif
