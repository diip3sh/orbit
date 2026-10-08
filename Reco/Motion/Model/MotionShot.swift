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
        /// New Raycast's macro: one control, on glass over satin, so close the frame cuts it off. The camera
        /// frames each stop's region in turn, holding and creeping, and whips from one to the next; a typing
        /// asset is typed into, a selection steps through its results.
        case macro
        /// Elements entering one after another.
        case uiCascade
        /// Features one at a time, never all at once.
        case featureSequence
        /// The logo, a headline and the address; still.
        case endCard
        /// New Raycast's closing on black: the name in small mono caps and the items' words swapped beside
        /// it, the last sliding in next to it, a line under them, then the logo alone.
        case closing

        /// Whether it shows ``MotionShot/text`` and ``MotionShot/detail``.
        var showsText: Bool {
            [.hook, .title, .endCard, .closing].contains(self)
        }

        var showsDetail: Bool {
            [.title, .endCard, .closing].contains(self)
        }

        /// Whether it holds still to the end, without the pacing's drift: a video's last word.
        var isEnding: Bool {
            self == .endCard || self == .closing
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

    /// What a macro's frame shows of its UI (``ShotItem/view``).
    var view: CGRect?

    /// What a macro frames in turn: its items with UI, or its own UI and view.
    var stops: [ShotItem] {
        items.map { $0.filter { $0.asset != nil } } ?? asset.map { [ShotItem(asset: $0, view: view)] } ?? []
    }

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
        if let misplaced = misplacedSlot {
            return misplaced
        }
        let hasText = !(text ?? "").isEmpty
        switch kind {
        case .hook, .title:
            return hasText ? nil : "\(kind.rawValue) needs text."
        case .uiHero, .uiFocus:
            return asset == nil ? "\(kind.rawValue) needs ui: the asset it shows." : nil
        case .macro:
            return macroProblem
        case .uiCascade:
            let items = items ?? []
            return items.count >= 2 && items.allSatisfy { $0.asset != nil } ? nil : "uiCascade needs two items or more, each with ui."
        case .featureSequence:
            let items = items ?? []
            return items.isEmpty || items.contains { $0.text == nil && $0.asset == nil } ? "featureSequence needs items, each with text or ui." : nil
        case .endCard:
            return hasText || asset != nil ? nil : "endCard needs text or ui (the logo)."
        case .closing:
            let words = (items ?? []).compactMap(\.text).filter { !$0.isEmpty }
            return hasText && !words.isEmpty ? nil : "closing needs text (the name) and items, each with text (the words swapped beside it)."
        }
    }
}

nonisolated private extension MotionShot {

    /// A slot filled that this shot doesn't show. Said rather than dropped: an agent's captions on a uiFocus
    /// never showed, and it only found out from the preview.
    var misplacedSlot: String? {
        if !(text ?? "").isEmpty, !kind.showsText {
            return "\(kind.rawValue) shows no text: put the line in a title or hook before it, or use featureSequence's items."
        }
        if !(detail ?? "").isEmpty, !kind.showsDetail {
            return "\(kind.rawValue) shows no detail."
        }
        return view != nil && kind != .macro ? "Only a macro has a view; a uiFocus frames its region." : nil
    }

    /// A macro's stops each show UI, and their views are boxes.
    var macroProblem: String? {
        guard !stops.isEmpty, stops.count == (items?.count ?? 1) else { return "macro needs ui, or items each with ui." }
        return stops.compactMap(\.view).allSatisfy { !$0.isEmpty && $0.width.isFinite && $0.height.isFinite }
            ? nil : "A macro's view is [[x, y], [width, height]] in CSS pixels from its UI's top-left corner."
    }
}

// MARK: - Codable

nonisolated extension MotionShot: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind = "shot"
        case text, detail, items, region, view
        case asset = "ui"
    }
}
