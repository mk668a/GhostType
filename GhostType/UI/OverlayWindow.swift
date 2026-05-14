import AppKit
import SwiftUI

final class OverlayWindowController {
    private let settings: AppSettings
    private var window: NSWindow?
    private(set) var currentText: String?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show(text: String, at cursorRect: CGRect) {
        currentText = text
        hide()

        let view = CompletionOverlayView(
            text: text,
            fontSize: settings.fontSize,
            opacity: settings.ghostTextOpacity
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame.size = hostingView.fittingSize

        // Limit width
        let maxWidth: CGFloat = 500
        if hostingView.frame.width > maxWidth {
            hostingView.frame.size.width = maxWidth
            hostingView.frame.size = hostingView.fittingSize
        }

        let contentSize = hostingView.frame.size

        // Convert AX screen coordinates (origin top-left) to NSScreen (origin bottom-left)
        // and position the overlay just below the cursor
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = cursorRect.origin.x
        var y = screenFrame.height - cursorRect.origin.y - cursorRect.height - contentSize.height

        // Clamp to screen bounds so the overlay is always visible
        x = max(screenFrame.minX, min(x, screenFrame.maxX - contentSize.width))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - contentSize.height))

        let windowFrame = NSRect(origin: CGPoint(x: x, y: y), size: contentSize)

        let overlayWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Use popUpMenu level to ensure overlay is above all normal app windows
        overlayWindow.level = .popUpMenu
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.hasShadow = true
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        overlayWindow.contentView = hostingView
        overlayWindow.animationBehavior = .utilityWindow

        // Show without activating GhostType (critical for LSUIElement apps)
        overlayWindow.orderFrontRegardless()

        self.window = overlayWindow
    }

    func hide() {
        guard let window else { return }
        window.orderOut(nil)
        self.window = nil
        self.currentText = nil
    }
}

// MARK: - SwiftUI Overlay View

struct CompletionOverlayView: View {
    let text: String
    let fontSize: Double
    let opacity: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.gray)
                .opacity(opacity)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "arrow.right.to.line")
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))
                .help("Press Tab to accept")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}
