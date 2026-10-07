//
//  EditorViewModel+Motion.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

extension EditorViewModel {

    /// How the camera moves between zooms, for the inspector's Motion tab. Each change is an edit.
    var zoomMotion: ZoomMotion {
        get { project.zoomMotion }
        set { edit("Zoom Motion") { $0.zoomMotion = newValue } }
    }
}
