//
//  BrowseRequest.swift
//  Reco
//

import Foundation

/// The arguments of the browsing tools (spec 0011); each uses some of them.
nonisolated struct BrowseRequest: Decodable, Sendable {
    /// open_page: the address; viewport is one of `WebScript.Viewport`'s names.
    var url: String?
    var viewport: String?

    /// look: where to scroll to, in CSS pixels from the page's top.
    var y: Double?

    /// click, hover, type: the element, by a selector from open_page or inspect_page.
    var selector: String?

    /// type: what to type into the element.
    var text: String?

    /// The selector the action `name` needs, trimmed.
    func requiredSelector(for name: String) throws(AgentToolError) -> String {
        let selector = selector?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !selector.isEmpty else { throw .invalidArgument("\(name) needs a selector from open_page or inspect_page.") }
        return selector
    }
}
