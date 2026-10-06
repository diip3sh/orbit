//
//  UICaptureError.swift
//  Reco
//

import Foundation

/// Why UI couldn't be lifted from a page.
nonisolated enum UICaptureError: LocalizedError, Equatable {

    /// Asset id and selector.
    case notFound(String, String)

    /// Asset id and selector: the element is wider than the viewport, or the page won't scroll it
    /// into view.
    case outOfView(String, String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id, let selector): "Asset \"\(id)\": the page has no element matching \(selector)."
        case .outOfView(let id, let selector): "Asset \"\(id)\": the element matching \(selector) can't be brought wholly into view."
        }
    }
}
