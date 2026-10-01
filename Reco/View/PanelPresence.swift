//
//  PanelPresence.swift
//  Reco
//

import Observation

/// Whether a panel is meant to be showing, for a controller whose view model can't carry the
/// flag: the view reads `isShown` into `panelPresentation(isPresented:anchor:)`.
@MainActor
@Observable
final class PanelPresence {
    var isShown = true
}
