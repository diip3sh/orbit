//
//  AreaSelectionViewDelegate.swift
//  Reco
//
//  Created by Diip3sh on 30.09.26.
//

import AppKit

@MainActor
protocol AreaSelectionViewDelegate: AnyObject {
    func areaSelectionView(_ view: AreaSelectionView, didConfirmSelection rect: CGRect, on screen: NSScreen)
    func areaSelectionViewDidCancel(_ view: AreaSelectionView)
    func areaSelectionViewDidBeginDrawing(_ view: AreaSelectionView)
}
