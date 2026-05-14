import AppKit
import ApplicationServices

struct TextContext {
    let prefix: String
    let suffix: String
    let cursorRect: CGRect
}

final class AccessibilityManager {
    static let shared = AccessibilityManager()

    private init() {}

    // MARK: - Permission Check

    /// Check if Accessibility permission is granted.
    /// Required for AX APIs (context read/insert) used by GhostType.
    func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    /// Check if Input Monitoring permission is granted.
    /// Optional: only needed for global shortcuts outside text fields.
    /// IMK handles all keystroke capture within text fields without this permission.
    func checkInputMonitoring() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// Show the system prompt to request Accessibility permission.
    /// Only call this when checkAccessibility() returns false.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Show the system prompt for Input Monitoring permission when available.
    /// Returns current/updated grant state.
    @discardableResult
    func requestInputMonitoring() -> Bool {
        CGRequestListenEventAccess()
    }

    /// Open System Settings directly to the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings directly to the Input Monitoring pane.
    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Frontmost App

    /// Bundle identifier of the application that currently owns keyboard focus.
    func focusedAppBundleID() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    // MARK: - Text Context Retrieval

    func getTextContext(maxChars: Int) -> TextContext? {
        guard let element = findBestTextElement() else {
            print("[GhostType AX] No text element found")
            return nil
        }

        // Strategy 1: AXValue + AXSelectedTextRange (native text fields, TextEdit, etc.)
        if let context = getContextViaValue(element: element, maxChars: maxChars) {
            return context
        }

        // Strategy 2: AXStringForRange (browsers, web apps, etc.)
        if let context = getContextViaSelectedText(element: element, maxChars: maxChars) {
            return context
        }

        print("[GhostType AX] Element found but no text attributes available (role: \(getRoleDescription(element)))")
        return nil
    }

    // MARK: - Text Insertion

    func insertText(_ text: String) {
        if let element = findBestTextElement() {
            // Try AXValue-based insertion first (native text fields)
            if let range = getSelectedRange(element),
               let fullText = getStringAttribute(element, attribute: kAXValueAttribute) {
                let nsString = fullText as NSString
                let insertionPoint = min(range.location, nsString.length)
                let before = nsString.substring(to: insertionPoint)
                let after = nsString.substring(from: insertionPoint)
                let newText = before + text + after

                let setResult = AXUIElementSetAttributeValue(
                    element, kAXValueAttribute as CFString, newText as CFTypeRef)
                if setResult == .success {
                    let newCursorPos = insertionPoint + text.count
                    setSelectedRange(element, range: NSRange(location: newCursorPos, length: 0))
                    return
                }
            }
        }

        // Fallback: clipboard-based insertion (universal)
        insertViaClipboard(text)
    }

    /// Get cursor position for overlay placement. Falls back through multiple strategies.
    func getCursorPosition() -> CGRect {
        if let element = findBestTextElement() {
            if let range = getSelectedRange(element) {
                let rect = getCursorRect(element, caretOffset: range.location)
                if rect.height > 0 { return rect }
            }
            let rect = getElementPosition(element)
            if rect.height > 0 { return rect }
        }

        // Last resort: use mouse position (converted to AX coordinates: top-left origin)
        let mouse = NSEvent.mouseLocation
        let screenH = NSScreen.main?.frame.height ?? 900
        return CGRect(x: mouse.x, y: screenH - mouse.y, width: 0, height: 18)
    }

    // MARK: - Find Best Text Element

    /// Walk the AX tree to find the element that actually holds editable text.
    /// This handles complex hierarchies like Safari web content, Notes, etc.
    private func findBestTextElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        // Step 1: Get the focused application
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else {
            print("[GhostType AX] No focused application")
            return nil
        }

        // Step 2: Get the focused UI element
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(
            app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else {
            print("[GhostType AX] No focused element in app")
            return nil
        }

        let axElement = element as! AXUIElement
        let role = getStringAttribute(axElement, attribute: kAXRoleAttribute) ?? "unknown"
        print("[GhostType AX] Focused element role: \(role)")

        // If the focused element already has text content, use it directly
        if hasTextContent(axElement) {
            return axElement
        }

        // For AXWebArea and AXGroup: try to find the focused child with text
        if let textChild = findTextElementInTree(axElement, depth: 0, maxDepth: 5) {
            return textChild
        }

        // Walk up to parent — focused element might be a button/label inside a text field
        if let parent = getParent(axElement), hasTextContent(parent) {
            return parent
        }

        // Return original element anyway — caller can try its own strategies
        return axElement
    }

    /// Recursively search the AX tree for an element with text content.
    /// Follows focused children first, then searches all children.
    private func findTextElementInTree(_ element: AXUIElement, depth: Int, maxDepth: Int) -> AXUIElement? {
        guard depth < maxDepth else { return nil }

        // Check if this element's focused child has text
        var focusedChild: AnyObject?
        if AXUIElementCopyAttributeValue(
            element, kAXFocusedUIElementAttribute as CFString, &focusedChild) == .success,
           let fc = focusedChild {
            let child = fc as! AXUIElement
            if hasTextContent(child) { return child }
            // Continue searching deeper through the focused child
            if let deeper = findTextElementInTree(child, depth: depth + 1, maxDepth: maxDepth) {
                return deeper
            }
        }

        // Search direct children for text-bearing roles
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else {
            return nil
        }

        // Limit to first 20 children to avoid excessive traversal
        let limit = min(childArray.count, 20)
        for i in 0..<limit {
            let child = childArray[i]
            let role = getStringAttribute(child, attribute: kAXRoleAttribute) ?? ""

            if role == kAXTextFieldRole as String ||
               role == kAXTextAreaRole as String ||
               role == kAXComboBoxRole as String {
                if hasTextContent(child) { return child }
            }

            // Recurse into web areas and groups
            if role == "AXWebArea" || role == kAXGroupRole as String {
                if let found = findTextElementInTree(child, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }

        return nil
    }

    /// Check if an element has text content we can read.
    private func hasTextContent(_ element: AXUIElement) -> Bool {
        // Has AXValue (full text)?
        if let val = getStringAttribute(element, attribute: kAXValueAttribute), !val.isEmpty {
            return true
        }
        // Has AXSelectedTextRange (cursor position)?
        if getSelectedRange(element) != nil {
            return true
        }
        return false
    }

    // MARK: - Context Extraction

    private func getContextViaValue(element: AXUIElement, maxChars: Int) -> TextContext? {
        guard let fullText = getStringAttribute(element, attribute: kAXValueAttribute),
              !fullText.isEmpty else {
            return nil
        }

        let selectedRange = getSelectedRange(element)
        let cursorPosition = selectedRange?.location ?? fullText.count

        guard cursorPosition <= fullText.count else { return nil }

        let prefixStart = max(0, cursorPosition - maxChars)
        let suffixEnd = min(fullText.count, cursorPosition + maxChars)

        let startIdx = fullText.index(fullText.startIndex, offsetBy: prefixStart)
        let cursorIdx = fullText.index(fullText.startIndex, offsetBy: cursorPosition)
        let endIdx = fullText.index(fullText.startIndex, offsetBy: suffixEnd)

        let prefix = String(fullText[startIdx..<cursorIdx])
        let suffix = String(fullText[cursorIdx..<endIdx])

        guard !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let cursorRect = getCursorRect(element, caretOffset: cursorPosition)
        return TextContext(prefix: prefix, suffix: suffix, cursorRect: cursorRect)
    }

    private func getContextViaSelectedText(element: AXUIElement, maxChars: Int) -> TextContext? {
        guard let selectedRange = getSelectedRange(element) else { return nil }

        let cursorPosition = selectedRange.location

        let prefixRange = NSRange(location: max(0, cursorPosition - maxChars),
                                  length: min(cursorPosition, maxChars))
        let prefix = getStringForRange(element, range: prefixRange) ?? ""

        let suffixStart = cursorPosition + selectedRange.length
        let suffixRange = NSRange(location: suffixStart, length: maxChars)
        let suffix = getStringForRange(element, range: suffixRange) ?? ""

        guard !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let cursorRect = getCursorRect(element, caretOffset: cursorPosition)
        return TextContext(prefix: prefix, suffix: suffix, cursorRect: cursorRect)
    }

    // MARK: - AX Helpers

    private func getStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func getSelectedRange(_ element: AXUIElement) -> NSRange? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }

        var range = CFRange(location: 0, length: 0)
        if AXValueGetValue(axValue as! AXValue, .cfRange, &range) {
            return NSRange(location: range.location, length: range.length)
        }
        return nil
    }

    private func setSelectedRange(_ element: AXUIElement, range: NSRange) {
        var cfRange = CFRange(location: range.location, length: range.length)
        if let value = AXValueCreate(.cfRange, &cfRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        }
    }

    private func getStringForRange(_ element: AXUIElement, range: NSRange) -> String? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }

        var result: AnyObject?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &result
        )
        guard err == .success else { return nil }
        return result as? String
    }

    private func getCursorRect(_ element: AXUIElement, caretOffset: Int) -> CGRect {
        var cfRange = CFRange(location: caretOffset, length: 0)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            return getElementPosition(element)
        }

        var bounds: AnyObject?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &bounds
        )

        if result == .success, let boundsValue = bounds {
            var rect = CGRect.zero
            if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect), rect.height > 0 {
                return rect
            }
        }

        return getElementPosition(element)
    }

    private func getElementPosition(_ element: AXUIElement) -> CGRect {
        var position: AnyObject?
        var size: AnyObject?

        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)

        var point = CGPoint.zero
        var axSize = CGSize.zero

        if let posValue = position {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        }
        if let sizeValue = size {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &axSize)
        }

        return CGRect(x: point.x, y: point.y, width: axSize.width, height: axSize.height)
    }

    private func getParent(_ element: AXUIElement) -> AXUIElement? {
        var parent: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent)
        guard result == .success, let p = parent else { return nil }
        return (p as! AXUIElement)
    }

    private func getRoleDescription(_ element: AXUIElement) -> String {
        let role = getStringAttribute(element, attribute: kAXRoleAttribute) ?? "?"
        let subrole = getStringAttribute(element, attribute: kAXSubroleAttribute) ?? ""
        return subrole.isEmpty ? role : "\(role)/\(subrole)"
    }

    private func insertViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Restore clipboard after a short delay
        if let old = oldContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
        }
    }
}
