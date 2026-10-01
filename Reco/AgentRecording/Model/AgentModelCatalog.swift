//
//  AgentModelCatalog.swift
//  Reco
//

/// The models the panel offers for each agent, besides its own default.
nonisolated enum AgentModelCatalog {

    /// As of 2026-10-01, from each CLI's documentation (spec 0007). They go stale: refresh them from
    /// the CLI's own list command (`codex debug models`, `gemini` /model, `grok models`, …).
    static func models(for kind: AgentKind) -> [String] {
        switch kind {
        case .claudeCode: ["opus", "sonnet", "fable"]
        case .codex: ["gpt-6-astra", "gpt-6.1-sol", "gpt-6-luna"]
        case .gemini: ["gemini-3-pro-preview", "gemini-3-flash-preview"]
        case .grok: ["grok-4.6", "grok-4.5"]
        // OpenCode wants provider/model, which depends on the user's providers; Cursor's list is
        // account-specific
        case .openCode, .cursor, .claudeDesktop: []
        }
    }
}
