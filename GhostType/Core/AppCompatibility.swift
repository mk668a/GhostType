import Foundation

/// What GhostType is allowed to do in the field the user is currently typing in.
///
/// Resolved fresh on every trigger from three inputs: the frontmost app, the
/// web domain when that app is a browser, and whether the focused element is a
/// secure field. Keeping this as resolved *data* rather than conditionals
/// scattered through the trigger path means "why did nothing happen here?" has
/// exactly one place to look.
struct CompletionPolicy: Equatable {
    /// No completions at all, and no keystroke buffering either.
    var completionsDisabled = false
    /// Auto-trigger off; the manual shortcut still works.
    var manualOnly = false
    /// Send only the text before the cursor. Some fields report a suffix that
    /// is not really there (composite web editors), and a bogus suffix makes
    /// fill-in-the-middle worse than plain continuation.
    var midLineDisabled = false
    /// The field holds a credential. Stricter than `completionsDisabled`: it
    /// also means the keystroke buffer must be dropped, not just unused.
    var secure = false

    static let unrestricted = CompletionPolicy()

    static let secureField = CompletionPolicy(
        completionsDisabled: true,
        manualOnly: true,
        midLineDisabled: true,
        secure: true
    )
}

/// Per-app and per-domain rules that are not user-configurable.
///
/// The Excluded Apps settings are the user's list. This is the floor beneath
/// it: places where completing would leak a credential or corrupt input, which
/// nobody should have to discover and add by hand.
enum AppCompatibility {
    /// Password managers. Their windows are full of credential fields that do
    /// not always carry the AX secure-field role, so the whole app is off.
    static let credentialAppBundleIDs: Set<String> = [
        "com.1password.1password",
        "com.1password.1password7",
        "com.agilebits.onepassword7",
        "com.apple.Passwords",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.dashlane.Dashlane",
        "com.lastpass.LastPass",
        "in.sinew.Enpass-Desktop",
        "me.proton.pass.electron",
        "com.markmcguill.strongbox.mac",
        "com.apple.keychainaccess",
    ]

    /// Sign-in and account surfaces, matched on the web domain so one rule
    /// covers Safari, Chrome, Arc, and anything else with an AX web area.
    /// A bundle-ID rule cannot do this: the browser is the same app either way.
    static let credentialDomains: Set<String> = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "appleid.apple.com",
        "signin.aws.amazon.com",
        "login.yahoo.co.jp",
        "id.smt.docomo.ne.jp",
        "vault.bitwarden.com",
        "my.1password.com",
    ]

    /// Web editors that report a suffix which does not match what is really
    /// after the cursor, so fill-in-the-middle sees a phantom tail.
    static let midLineProblemDomains: Set<String> = [
        "docs.google.com",
        "www.notion.so",
        "notion.so",
    ]

    static func policy(bundleID: String?, domain: String?, focusedFieldIsSecure: Bool) -> CompletionPolicy {
        if focusedFieldIsSecure { return .secureField }

        if let bundleID, credentialAppBundleIDs.contains(bundleID) {
            return .secureField
        }

        if let domain = domain.map(normalize) {
            if credentialDomains.contains(where: { domain == $0 || domain.hasSuffix("." + $0) }) {
                return .secureField
            }
            if midLineProblemDomains.contains(domain) {
                return CompletionPolicy(midLineDisabled: true)
            }
        }

        return .unrestricted
    }

    /// Strips a leading `www.` and lowercases, so `WWW.Notion.so` and
    /// `notion.so` resolve to the same rule.
    private static func normalize(_ host: String) -> String {
        var host = host.lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}
