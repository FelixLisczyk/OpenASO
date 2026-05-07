import AppKit
import SwiftUI

struct Tooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(width: 280, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18))
            }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
    }
}

private struct TooltipModifier: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        content
            .accessibilityHint(Text(text))
            .background(TooltipAnchor(text: text))
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        modifier(TooltipModifier(text: text))
    }
}

private struct TooltipAnchor: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> TooltipTrackingView {
        let view = TooltipTrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TooltipTrackingView, context: Context) {
        context.coordinator.text = text
        nsView.coordinator = context.coordinator

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.coordinator.hide()
        } else {
            context.coordinator.updateVisiblePanelPosition(from: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text)
    }

    static func dismantleNSView(_ nsView: TooltipTrackingView, coordinator: Coordinator) {
        coordinator.hide()
        nsView.coordinator = nil
    }

    @MainActor
    final class Coordinator {
        var text: String

        private var isHovering = false

        init(text: String) {
            self.text = text
        }

        func mouseEntered(view: NSView) {
            isHovering = true
            show(from: view)
        }

        func mouseExited() {
            isHovering = false
            hide()
        }

        func updateVisiblePanelPosition(from view: NSView) {
            guard isHovering else { return }
            show(from: view)
        }

        func hide() {
            TooltipPanelController.shared.hide(owner: self)
        }

        private func show(from view: NSView) {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                hide()
                return
            }

            TooltipPanelController.shared.show(text: trimmedText, anchoredTo: view, owner: self)
        }
    }
}

private final class TooltipTrackingView: NSView {
    weak var coordinator: TooltipAnchor.Coordinator?

    private var trackingAreaReference: NSTrackingArea?
    private weak var observedClipView: NSClipView?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.mouseEntered(view: self)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.mouseExited()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        NotificationCenter.default.removeObserver(self)
        observedClipView = nil

        guard let window else {
            coordinator?.hide()
            return
        }

        let notificationCenter = NotificationCenter.default
        for name in [
            NSWindow.willCloseNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didMiniaturizeNotification
        ] {
            notificationCenter.addObserver(
                self,
                selector: #selector(hideTooltipForWindowLifecycleChange(_:)),
                name: name,
                object: window
            )
        }

        if let clipView = enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            observedClipView = clipView
            notificationCenter.addObserver(
                self,
                selector: #selector(hideTooltipForScrollChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        if superview == nil {
            NotificationCenter.default.removeObserver(self)
            observedClipView = nil
            coordinator?.hide()
        }
    }

    @objc private func hideTooltipForWindowLifecycleChange(_ notification: Notification) {
        coordinator?.hide()
    }

    @objc private func hideTooltipForScrollChange(_ notification: Notification) {
        coordinator?.hide()
    }
}

@MainActor
private final class TooltipPanelController {
    static let shared = TooltipPanelController()

    private weak var owner: AnyObject?
    private var panel: NSPanel?
    private var hostingView: NSHostingView<Tooltip>?

    private init() {}

    func show(text: String, anchoredTo anchorView: NSView, owner: AnyObject) {
        guard let screenRect = screenRect(for: anchorView) else {
            hide(owner: owner)
            return
        }

        self.owner = owner

        let panel = panel ?? makePanel()
        let hostingView = hostingView ?? NSHostingView(rootView: Tooltip(text: text))
        hostingView.rootView = Tooltip(text: text)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]

        if panel.contentView !== hostingView {
            panel.contentView = hostingView
        }

        let panelSize = measuredPanelSize(for: hostingView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        panel.setFrame(NSRect(origin: .zero, size: panelSize), display: false)
        panel.setFrameOrigin(origin(for: panelSize, anchorRect: screenRect, screen: anchorView.window?.screen))

        if panel.parent !== anchorView.window {
            panel.parent?.removeChildWindow(panel)
        }
        if panel.parent == nil, let window = anchorView.window {
            window.addChildWindow(panel, ordered: .above)
        }

        panel.orderFrontRegardless()
        self.panel = panel
        self.hostingView = hostingView
    }

    func hide(owner: AnyObject? = nil) {
        if let owner, self.owner !== owner {
            return
        }

        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        self.owner = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isOpaque = false
        panel.level = .floating
        panel.titleVisibility = .hidden
        return panel
    }

    private func measuredPanelSize(for hostingView: NSHostingView<Tooltip>) -> CGSize {
        let maximumWidth: CGFloat = 320
        hostingView.frame = NSRect(x: 0, y: 0, width: maximumWidth, height: 1)
        hostingView.layoutSubtreeIfNeeded()

        let constrainedSize = hostingView.fittingSize
        return CGSize(
            width: min(max(ceil(constrainedSize.width), 1), maximumWidth),
            height: max(ceil(constrainedSize.height), 1)
        )
    }

    private func screenRect(for view: NSView) -> NSRect? {
        guard let window = view.window else { return nil }

        let localRect = view.convert(view.bounds, to: nil)
        return window.convertToScreen(localRect)
    }

    private func origin(for panelSize: CGSize, anchorRect: NSRect, screen: NSScreen?) -> CGPoint {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let spacing: CGFloat = 0

        var x = anchorRect.midX - (panelSize.width / 2)
        var y = anchorRect.minY - panelSize.height - spacing

        if y < visibleFrame.minY {
            y = visibleFrame.minY + spacing
        }

        x = min(max(x, visibleFrame.minX + spacing), visibleFrame.maxX - panelSize.width - spacing)
        y = min(max(y, visibleFrame.minY + spacing), visibleFrame.maxY - panelSize.height - spacing)

        return CGPoint(x: x, y: y)
    }
}
