import Foundation

/// A GGUF model GhostType knows how to fetch for the embedded backend.
///
/// The catalog is intentionally tiny and opinionated. Picking a model is the
/// one decision that stands between "downloaded the app" and "it completes my
/// sentences", so the list stays short enough to read in one glance, and every
/// entry is a model whose FIM tokens llama.cpp already understands.
struct CatalogModel: Identifiable, Hashable {
    /// What the model is good at, which is the only distinction a user picking
    /// from this list actually needs to make.
    enum Kind: Hashable {
        case prose
        case code

        var sectionTitle: String {
            switch self {
            case .prose: return String(localized: "For writing")
            case .code:  return String(localized: "For code")
            }
        }
    }

    let id: String
    let displayName: String
    let kind: Kind
    /// Hugging Face repo in `owner/name` form.
    let repo: String
    let file: String
    let sizeBytes: Int64
    let summary: String

    var downloadURL: URL {
        URL(string: "https://huggingface.co/\(repo)/resolve/main/\(file)?download=true")!
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    static let all: [CatalogModel] = [
        // Base models, not instruct or code models. A base model's entire
        // training objective is "continue this text", which is exactly what an
        // inline completion is. An earlier version of this catalog shipped
        // Qwen2.5-Coder as the default because it was the small model whose FIM
        // tokens llama.cpp definitely understood, but optimizing for that made
        // prose completions noticeably worse: a code model asked to finish an
        // email writes like one.
        CatalogModel(
            id: "qwen3.5-0.8b-base-q6_k",
            displayName: "Qwen3.5 0.8B Base",
            kind: .prose,
            repo: "mradermacher/Qwen3.5-0.8B-Base-i1-GGUF",
            file: "Qwen3.5-0.8B-Base.i1-Q6_K.gguf",
            sizeBytes: 629_744_512,
            summary: String(localized: "Fastest. Good on older Macs and 8 GB memory.")
        ),
        CatalogModel(
            id: "qwen3.5-2b-base-q4_k_m",
            displayName: "Qwen3.5 2B Base",
            kind: .prose,
            repo: "mradermacher/Qwen3.5-2B-Base-i1-GGUF",
            file: "Qwen3.5-2B-Base.i1-Q4_K_M.gguf",
            sizeBytes: 1_274_397_056,
            summary: String(localized: "Recommended. Best latency-to-quality balance on Apple Silicon.")
        ),
        CatalogModel(
            id: "qwen3.5-4b-base-q4_k_m",
            displayName: "Qwen3.5 4B Base",
            kind: .prose,
            repo: "mradermacher/Qwen3.5-4B-Base-i1-GGUF",
            file: "Qwen3.5-4B-Base.i1-Q4_K_M.gguf",
            sizeBytes: 2_708_804_864,
            summary: String(localized: "Highest quality. Wants 16 GB memory or more.")
        ),

        // Kept for people who do want completions inside code. These are the
        // ggml-org conversions llama.vim and llama.vscode use, so their FIM
        // token metadata is known-good with `/infill`.
        CatalogModel(
            id: "qwen2.5-coder-0.5b-q8_0",
            displayName: "Qwen2.5-Coder 0.5B",
            kind: .code,
            repo: "ggml-org/Qwen2.5-Coder-0.5B-Q8_0-GGUF",
            file: "qwen2.5-coder-0.5b-q8_0.gguf",
            sizeBytes: 531_068_128,
            summary: String(localized: "Lightweight. For code and technical writing.")
        ),
        CatalogModel(
            id: "qwen2.5-coder-1.5b-q8_0",
            displayName: "Qwen2.5-Coder 1.5B",
            kind: .code,
            repo: "ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF",
            file: "qwen2.5-coder-1.5b-q8_0.gguf",
            sizeBytes: 1_646_573_056,
            summary: String(localized: "Stronger on code. Weaker on everyday prose.")
        ),
    ]

    static let recommended = all[1]

    static func models(ofKind kind: Kind) -> [CatalogModel] {
        all.filter { $0.kind == kind }
    }

    static func model(withID id: String) -> CatalogModel? {
        all.first { $0.id == id }
    }
}

/// Filesystem layout for downloaded models.
enum ModelStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("GhostType/models", isDirectory: true)
    }

    static func localURL(for model: CatalogModel) -> URL {
        directory.appendingPathComponent(model.file)
    }

    /// A model counts as installed only when the file on disk is the size the
    /// catalog expects. A partial download left behind by a crash or a quit
    /// would otherwise be handed straight to llama.cpp, which fails with a
    /// GGUF parse error the user cannot interpret.
    static func isInstalled(_ model: CatalogModel) -> Bool {
        let url = localURL(for: model)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else { return false }
        return size >= Int64(Double(model.sizeBytes) * 0.98)
    }

    static func installedSize(_ model: CatalogModel) -> Int64? {
        let url = localURL(for: model)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else { return nil }
        return size
    }

    static func remove(_ model: CatalogModel) throws {
        let url = localURL(for: model)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
