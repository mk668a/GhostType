import Foundation

/// Builds the GBNF grammar that constrains an inline completion.
///
/// Sampling alone cannot stop a chat-tuned model from answering an inline
/// completion with a code fence, a quoted restatement, or three paragraphs of
/// explanation. Post-processing that output is guesswork after the fact; a
/// grammar makes those tokens unreachable in the first place, which is both
/// more reliable and faster, because the model never spends tokens on text we
/// were going to throw away.
enum CompletionGrammar {
    enum Style: String, CaseIterable, Identifiable {
        /// One line, no leading fence. The right default for prose typed into
        /// a mail client, a browser field, or a chat box.
        case singleLine
        /// Up to a handful of lines, for editors and multi-line text areas.
        case shortBlock
        /// No constraint at all — hand the model the raw sampler.
        case unconstrained

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .singleLine:    return String(localized: "Single line")
            case .shortBlock:    return String(localized: "Up to a few lines")
            case .unconstrained: return String(localized: "Unconstrained")
            }
        }

        var summary: String {
            switch self {
            case .singleLine:
                return String(localized: "Best for email, chat, and browser fields. Blocks newlines and code fences.")
            case .shortBlock:
                return String(localized: "Allows short multi-line completions. Better for editors and notes.")
            case .unconstrained:
                return String(localized: "No grammar. Use if a model behaves oddly under constraints.")
            }
        }
    }

    /// Maximum extra lines permitted by `.shortBlock`.
    private static let shortBlockExtraLines = 3

    /// Returns the GBNF source for `style`, or nil when no grammar applies.
    ///
    /// `firstchar` excludes a leading backtick so the model cannot open a
    /// markdown fence, while still allowing a leading space — a completion for
    /// "Hello" is usually " world", not "world".
    static func gbnf(for style: Style) -> String? {
        switch style {
        case .unconstrained:
            return nil
        case .singleLine:
            return """
            root ::= firstchar rest*
            firstchar ::= [^\\n\\r`]
            rest ::= [^\\n\\r]
            """
        case .shortBlock:
            return """
            root ::= firstline (newline line){0,\(shortBlockExtraLines)}
            firstline ::= firstchar rest*
            firstchar ::= [^\\n\\r`]
            rest ::= [^\\n\\r]
            line ::= rest*
            newline ::= "\\n"
            """
        }
    }

    /// Picks a style for the field the user is actually typing in.
    ///
    /// A single-line control cannot render a newline anyway, so letting the
    /// model produce one only wastes tokens and then gets stripped.
    static func style(preferred: Style, fieldIsMultiline: Bool) -> Style {
        guard preferred == .shortBlock, !fieldIsMultiline else { return preferred }
        return .singleLine
    }
}
