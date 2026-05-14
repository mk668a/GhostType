import SwiftUI

/// A more detailed completion popup with multiple suggestions support.
struct CompletionPopup: View {
    let suggestions: [String]
    let selectedIndex: Int
    let fontSize: Double
    let opacity: Double
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if suggestions.isEmpty {
                EmptyView()
            } else {
                // Main suggestion
                Text(suggestions[selectedIndex])
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(.gray)
                    .opacity(opacity)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                // Bottom bar with hints
                if suggestions.count > 1 {
                    Divider()
                    HStack {
                        Text("\(selectedIndex + 1)/\(suggestions.count)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)

                        Spacer()

                        HStack(spacing: 8) {
                            KeyHint(key: "Tab", label: "Accept")
                            KeyHint(key: "Esc", label: "Dismiss")
                            if suggestions.count > 1 {
                                KeyHint(key: "Opt+]", label: "Next")
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: 500)
    }
}

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 2) {
            Text(key)
                .font(.system(size: 9, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(3)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}
