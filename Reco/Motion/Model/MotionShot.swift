//
//  MotionShot.swift
//  Reco
//

import CoreGraphics

/// A shot from the grammar's catalogue filling a scene: its slots (text, a UI asset, items) laid out
/// by ``ShotLayout`` into layers with moves and a camera. The scene's own layers are drawn over them;
/// one with a shot layer's id replaces it.
///
/// Coded `{"shot": "title", "text": "Ship faster."}`.
nonisolated struct MotionShot: Equatable, Sendable {

    nonisolated enum Kind: String, Codable, CaseIterable, Sendable {
        /// Six words at most over the product, dimmed.
        case hook
        /// Type alone: a headline and a line under it; the headline's last word rolls through the items' text.
        case title
        /// The product on a plane lying back, drifting, with a band in focus.
        case uiHero
        /// One element close up, flat: typing or clicking in a live take.
        case uiFocus
        /// Elements entering one after another.
        case uiCascade
        /// Features one at a time, never all at once.
        case featureSequence
        /// The logo, a headline and the address; still.
        case endCard

        /// Whether it shows ``MotionShot/text`` and ``MotionShot/detail``.
        var showsText: Bool {
            [.hook, .title, .endCard].contains(self)
        }

        var showsDetail: Bool {
            self == .title || self == .endCard
        }
    }

    var kind: Kind
    var text: String?

    /// A line under the text: a subtitle, an address, a call to action.
    var detail: String?

    /// A ``MotionAsset``'s id: the product (hook, uiHero, uiFocus) or the logo (endCard); coded `ui`.
    var asset: String?

    var items: [ShotItem]?

    /// The element a uiFocus frames, in fractions of the UI from its top-left corner.
    var region: CGRect?

    init(_ kind: Kind, text: String? = nil, detail: String? = nil, asset: String? = nil) {
        self.kind = kind
        self.text = text
        self.detail = detail
        self.asset = asset
    }
}

// MARK: - Validation

nonisolated extension MotionShot {

    /// What's wrong with this shot's slots, given the document's asset ids.
    func problem(assets: Set<String>) -> String? {
        let named = [asset] + (items ?? []).map(\.asset)
        if let unknown = named.compactMap({ $0 }).first(where: { !assets.contains($0) }) {
            return "\"\(unknown)\" isn't one of the document's assets."
        }
        let hasText = !(text ?? "").isEmpty
        // Said rather than dropped: an agent's captions on a uiFocus never showed, and it only found out from the preview
        if hasText, !kind.showsText {
            return "\(kind.rawValue) shows no text: put the line in a title or hook before it, or use featureSequence's items."
        }
        if !(detail ?? "").isEmpty, !kind.showsDetail {
            return "\(kind.rawValue) shows no detail."
        }
        switch kind {
        case .hook, .title:
            return hasText ? nil : "\(kind.rawValue) needs text."
        case .uiHero, .uiFocus:
            return asset == nil ? "\(kind.rawValue) needs ui: the asset it shows." : nil
        case .uiCascade:
            let items = items ?? []
            return items.count >= 2 && items.allSatisfy { $0.asset != nil } ? nil : "uiCascade needs two items or more, each with ui."
        case .featureSequence:
            let items = items ?? []
            return items.isEmpty || items.contains { $0.text == nil && $0.asset == nil } ? "featureSequence needs items, each with text or ui." : nil
        case .endCard:
            return hasText || asset != nil ? nil : "endCard needs text or ui (the logo)."
        }
    }
}

// MARK: - Codable

nonisolated extension MotionShot: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind = "shot"
        case text, detail, items, region
        case asset = "ui"
    }
}
