//
//  PointerClip+Presentation.swift
//  Reco
//

import Foundation

/// How a cursor clip's action reads in the window: its name and symbol.
extension PointerClip.Action {

    var title: String {
        switch self {
        case .hover: "Hover"
        case .click: "Click"
        case .type: "Type"
        }
    }

    var symbol: String {
        switch self {
        case .hover: "cursorarrow"
        case .click: "cursorarrow.click"
        case .type: "keyboard"
        }
    }
}
